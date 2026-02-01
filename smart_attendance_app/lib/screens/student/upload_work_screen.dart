import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class UploadWorkScreen extends StatefulWidget {
  final int taskId;
  final bool isSubmitted;

  const UploadWorkScreen({super.key, required this.taskId, required this.isSubmitted});

  @override
  State<UploadWorkScreen> createState() => _UploadWorkScreenState();
}

class _UploadWorkScreenState extends State<UploadWorkScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _task;
  Map<String, dynamic>? _submission;
  
  File? _selectedFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final task = await _apiService.getTaskDetails(widget.taskId);
      final submission = await _apiService.getMySubmission(widget.taskId);
      
      if (mounted) {
        setState(() {
          _task = task;
          _submission = submission;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
    );
    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _uploadWork() async {
    if (_selectedFile == null) return;

    setState(() => _isUploading = true);
    try {
      await _apiService.submitTask(taskId: widget.taskId, file: _selectedFile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work Submitted Successfully!')));
        _loadDetails(); // Refresh to show submitted state
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _downloadTaskAttachment() async {
    if (_task == null) return;
    final url = _apiService.getTaskFileUrl(widget.taskId);
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
  
  Future<void> _viewMySubmission() async {
    if (_submission == null) return;
    final url = _apiService.getSubmissionFileUrl(_submission!['submission_id']);
    if (await canLaunchUrl(Uri.parse(url))) {
       await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_task == null) return const Scaffold(body: Center(child: Text("Task not found")));

    final isSubmitted = _submission != null;
    final status = _submission != null ? _submission!['status'] : 'Not Submitted';
    
    return Scaffold(
      appBar: AppBar(title: Text(_task!['title'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _task!['title'],
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Subject: ${_task!['subject_code']}',
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Description:', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    _task!['description'] ?? 'No description',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                  ),
                   const SizedBox(height: 16),
                   if (_task!['file_path'] != null)
                      OutlinedButton.icon(
                        onPressed: _downloadTaskAttachment,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('View Attachment'),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Submission Section
            Text(
              'Your Work',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            
            if (!isSubmitted) ...[
              // Not Submitted UI
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload, size: 48, color: AppTheme.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      'Upload your solution (PDF/Image)',
                      style: GoogleFonts.inter(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    
                    if(_selectedFile != null)
                        Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                                children: [
                                    const Icon(Icons.file_present),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_selectedFile!.path.split('/').last, overflow: TextOverflow.ellipsis)),
                                    IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => setState(() => _selectedFile = null),
                                    )
                                ]
                            ),
                        ),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selectedFile == null ? _pickFile : (_isLoading ? null : _uploadWork),
                        icon: Icon(_selectedFile == null ? Icons.folder_open : Icons.send),
                        label: _isUploading 
                             ? const CircularProgressIndicator(color: Colors.white)
                             : Text(_selectedFile == null ? 'Select File' : 'Submit Work'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedFile == null ? AppTheme.secondaryColor : AppTheme.primaryColor
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Submitted UI
              Container(
                 padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(
                   color: AppTheme.bgCard,
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(color: Colors.green.withOpacity(0.5)),
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                       Row(
                           children: [
                               const Icon(Icons.check_circle, color: Colors.green),
                               const SizedBox(width: 8),
                               Text('Status: $status', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                           ],
                       ),
                       const SizedBox(height: 16),
                       OutlinedButton.icon(
                           onPressed: _viewMySubmission,
                           icon: const Icon(Icons.visibility),
                           label: const Text('View My Submission')
                       ),
                       
                       // Marks
                       if (_submission!['marks_obtained'] != null) ...[
                           Divider(height: 32, color: AppTheme.borderColor),
                           Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                   const Text('Marks:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                   Text(
                                       '${_submission!['marks_obtained']} / ${_task!['max_marks']}',
                                       style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                   ),
                               ],
                           ),
                       ],
                       
                       // Remarks
                       if (_submission!['remarks'] != null && _submission!['remarks'].toString().isNotEmpty) ...[
                           const SizedBox(height: 12),
                           const Text('Remarks:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                           const SizedBox(height: 4),
                           Text(_submission!['remarks'], style: const TextStyle(fontStyle: FontStyle.italic)),
                       ],
                   ],
                 ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
