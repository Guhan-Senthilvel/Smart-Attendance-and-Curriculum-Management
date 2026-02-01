# Smart Attendance System - Backend

## Quick Start

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Run the server:
```bash
cd c:\Users\guhan\Desktop\samrt-learn
python -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

3. Open API docs: http://localhost:8000/docs

## For GPU Support (NVIDIA RTX 3060)
```bash
pip uninstall onnxruntime
pip install onnxruntime-gpu
```

Set environment variable:
```bash
$env:AI_DEVICE = "gpu"
```
