import os
from typing import Dict, List, Tuple

import cv2
import numpy as np
from insightface.app import FaceAnalysis
from scipy.spatial.distance import cosine


SIMILARITY_THRESHOLD = 0.4  # how strict the match is


def _get_providers() -> List[str]:
    """
    Prefer GPU when available, with CPU fallback.

    In Docker with NVIDIA Container Toolkit, CUDAExecutionProvider will be
    available and used automatically.
    """
    # Allow override via env for debugging: "CPU" or "GPU"
    mode = os.getenv("AI_DEVICE", "").lower()
    if mode == "cpu":
        return ["CPUExecutionProvider"]
    if mode == "gpu":
        return ["CUDAExecutionProvider", "CPUExecutionProvider"]

    # Default: try GPU then CPU
    return ["CUDAExecutionProvider", "CPUExecutionProvider"]


class FaceAttendanceEngine:
    """
    Wraps InsightFace detection + recognition with the smart tiling logic
    from the standalone attendance_system.py.
    """

    def __init__(self) -> None:
        providers = _get_providers()
        self.app = FaceAnalysis(name="buffalo_l", providers=providers)
        # ctx_id = 0 will use GPU 0 when CUDAExecutionProvider is active,
        # or fall back to CPU execution otherwise.
        self.app.prepare(ctx_id=0, det_size=(640, 640))

    @staticmethod
    def _get_smart_tiles(full_img: np.ndarray) -> List[Tuple[np.ndarray, int, int]]:
        """
        Dynamically slices image into overlapping tiles to ensure no face is split.
        Uses a 2x3 grid (2 rows, 3 cols) with significant overlap.
        """
        h, w = full_img.shape[:2]
        tiles: List[Tuple[np.ndarray, int, int]] = []

        # Define overlapping intervals
        # Vertical: 2 rows with overlap
        # Row 1: 0% to 60%
        # Row 2: 40% to 100%
        y_intervals = [
            (0, int(h * 0.60)),
            (int(h * 0.40), h)
        ]

        # Horizontal: 3 cols with overlap
        # Col 1: 0% to 45%
        # Col 2: 30% to 75%  <-- Centered roughly
        # Col 3: 55% to 100%
        x_intervals = [
            (0, int(w * 0.45)),
            (int(w * 0.30), int(w * 0.75)),
            (int(w * 0.55), w)
        ]

        for y_start, y_end in y_intervals:
            for x_start, x_end in x_intervals:
                tile = full_img[y_start:y_end, x_start:x_end]
                tiles.append((tile, x_start, y_start))

        return tiles

    @staticmethod
    def _simple_nms(faces, iou_thresh: float = 0.4):
        """Removes duplicates from overlapping tiles."""
        if not faces:
            return []
        faces = sorted(faces, key=lambda x: x.det_score, reverse=True)
        keep = []
        while faces:
            current = faces.pop(0)
            keep.append(current)
            remaining = []
            for other in faces:
                xA = max(current.bbox[0], other.bbox[0])
                yA = max(current.bbox[1], other.bbox[1])
                xB = min(current.bbox[2], other.bbox[2])
                yB = min(current.bbox[3], other.bbox[3])
                interArea = max(0, xB - xA) * max(0, yB - yA)
                boxAArea = (current.bbox[2] - current.bbox[0]) * (
                    current.bbox[3] - current.bbox[1]
                )
                boxBArea = (other.bbox[2] - other.bbox[0]) * (
                    other.bbox[3] - other.bbox[1]
                )
                denom = float(boxAArea + boxBArea - interArea) or 1.0
                iou = interArea / denom
                if iou < iou_thresh:
                    remaining.append(other)
            faces = remaining
        return keep

    @staticmethod
    def _find_match(
        face_embedding: np.ndarray, database: Dict[str, np.ndarray]
    ) -> Tuple[str, float]:
        best_name = "Unknown"
        highest_similarity = 0.0
        for name, db_embedding in database.items():
            sim = 1 - cosine(face_embedding, db_embedding)
            if sim > highest_similarity:
                highest_similarity = sim
                best_name = name
        if highest_similarity > SIMILARITY_THRESHOLD:
            return best_name, highest_similarity
        return "Unknown", highest_similarity

    def mark_attendance(
        self,
        full_img: np.ndarray,
        embedding_db: Dict[str, np.ndarray],
    ) -> Tuple[List[str], List[str], np.ndarray]:
        """
        Run detection + recognition on an image and return:
        - present_reg_nos
        - absent_reg_nos
        - annotated_image (for proof)
        """
        if full_img is None:
            raise ValueError("Input image is None")

        tiles = self._get_smart_tiles(full_img)
        all_detections = []
        for tile_img, off_x, off_y in tiles:
            faces = self.app.get(tile_img)
            for face in faces:
                face.bbox[0] += off_x
                face.bbox[1] += off_y
                face.bbox[2] += off_x
                face.bbox[3] += off_y
                face.kps[:, 0] += off_x
                face.kps[:, 1] += off_y
                all_detections.append(face)

        unique_faces = self._simple_nms(all_detections)

        present_list: List[str] = []
        for face in unique_faces:
            name, sim_score = self._find_match(face.normed_embedding, embedding_db)
            box = face.bbox.astype(int)
            color = (0, 0, 255)  # red default
            label = f"Unknown"

            if name != "Unknown":
                present_list.append(name)
                color = (0, 255, 0)
                label = f"{name} ({int(sim_score * 100)}%)"

            cv2.putText(
                full_img,
                label,
                (box[0], box[1] - 10),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.8,
                color,
                2,
            )
            cv2.rectangle(
                full_img, (box[0], box[1]), (box[2], box[3]), color, 2
            )

        all_students = list(embedding_db.keys())
        absent_list = [s for s in all_students if s not in present_list]
        return present_list, absent_list, full_img


# Singleton instance
_engine_instance = None

def get_engine() -> FaceAttendanceEngine:
    global _engine_instance
    if _engine_instance is None:
        print("🔵 Loading InsightFace AI models (Lazy Load)...")
        _engine_instance = FaceAttendanceEngine()
        print("✅ InsightFace models loaded successfully")
    return _engine_instance

