import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class TaskSubmissionsScreen extends StatefulWidget {
  final int taskId;
  final String taskTitle;

  const TaskSubmissionsScreen({super.key, required this.taskId, required this.taskTitle});

  @override
  State<TaskSubmissionsScreen> createState() => _TaskSubmissionsScreenState();
}

class _TaskSubmissionsScreenState extends State<TaskSubmissionsScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _submissions = []; // Contains All Students (some with dummy submission data)

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    try {
      final data = await _apiService.getTaskSubmissions(widget.taskId);
      setState(() {
        _submissions = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _downloadFile(int submissionId) async {
    final url = _apiService.getSubmissionFileUrl(submissionId);
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open file')));
    }
  }

  Future<void> _saveEvaluation(int submissionId, String marks, String remarks) async {
    try {
      await _apiService.evaluateSubmission(
        submissionId: submissionId,
        marks: double.parse(marks),
        remarks: remarks,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evaluation Saved!')));
      _loadSubmissions(); // Refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.taskTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _submissions.length,
              itemBuilder: (context, index) {
                final sub = _submissions[index];
                final isSubmitted = sub['status'] != 'Not Submitted';
                
                return _SubmissionTile(
                  submission: sub,
                  onDownload: () => _downloadFile(sub['submission_id']),
                  onSave: (marks, remarks) => _saveEvaluation(sub['submission_id'], marks, remarks),
                  isSubmitted: isSubmitted,
                );
              },
            ),
    );
  }
}

class _SubmissionTile extends StatefulWidget {
  final Map<String, dynamic> submission;
  final VoidCallback onDownload;
  final Function(String, String) onSave;
  final bool isSubmitted;

  const _SubmissionTile({
    required this.submission,
    required this.onDownload,
    required this.onSave,
    required this.isSubmitted,
  });

  @override
  State<_SubmissionTile> createState() => _SubmissionTileState();
}

class _SubmissionTileState extends State<_SubmissionTile> {
  late TextEditingController _marksController;
  late TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    _marksController = TextEditingController(text: widget.submission['marks_obtained']?.toString() ?? '');
    _remarksController = TextEditingController(text: widget.submission['remarks'] ?? '');
  }

  @override
  void dispose() {
    _marksController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    if (widget.submission['status'] == 'Submitted') statusColor = Colors.blue;
    else if (widget.submission['status'] == 'Graded') statusColor = Colors.green;
    else statusColor = Colors.red;

    return Card(
      elevation: 0,
       shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.borderColor)
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          widget.submission['student_name'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(widget.submission['reg_no'] ?? ''),
        trailing: Container(
           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
           decoration: BoxDecoration(
             color: statusColor.withOpacity(0.1),
             borderRadius: BorderRadius.circular(8),
             border: Border.all(color: statusColor),
           ),
           child: Text(
             widget.submission['status'],
             style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
           ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: widget.isSubmitted
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Download
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: widget.onDownload,
                          icon: const Icon(Icons.download),
                          label: const Text('Download Submission'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Grading Form
                      TextField(
                        controller: _marksController,
                        decoration: const InputDecoration(labelText: 'Marks'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _remarksController,
                        decoration: const InputDecoration(labelText: 'Remarks'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => widget.onSave(_marksController.text, _remarksController.text),
                          child: const Text('Save Evaluation'),
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No work submitted by this student.', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
