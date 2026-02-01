import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class UploadEBookScreen extends StatefulWidget {
  const UploadEBookScreen({super.key});

  @override
  State<UploadEBookScreen> createState() => _UploadEBookScreenState();
}

class _UploadEBookScreenState extends State<UploadEBookScreen> {
  final _apiService = ApiService();
  
  List<dynamic> _classes = [];
  // Since user said "Select Subject", and subjects are linked to classes/teachers. 
  // We'll extract unique subjects from the teacher's classes.
  List<Map<String, String>> _uniqueSubjects = [];
  
  String? _selectedSubjectCode;
  List<PlatformFile> _selectedFiles = [];
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => _isLoading = true);
    try {
      final classes = await _apiService.getTeacherClasses();
      // Extract unique subjects: {code: "CS101", name: "DBMS"}
      final Set<String> codes = {};
      final List<Map<String, String>> subjects = [];
      
      for (var c in classes) {
        final code = c['subject_code'];
        final name = c['subject_name'] ?? code;
        
        if (!codes.contains(code)) {
          codes.add(code);
          subjects.add({'code': code, 'name': name});
        }
      }
      
      setState(() {
        _classes = classes;
        _uniqueSubjects = subjects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading subjects: $e')));
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking files: $e')));
    }
  }

  Future<void> _uploadFiles() async {
    if (_selectedSubjectCode == null || _selectedFiles.isEmpty) return;

    setState(() => _isUploading = true);

    int successCount = 0;
    List<String> validExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

    for (var file in _selectedFiles) {
        try {
            // Basic validation
            if (file.path == null) continue;
            
            await _apiService.uploadEBook(
                subjectCode: _selectedSubjectCode!,
                title: file.name, // Use filename as title for now
                file: File(file.path!),
            );
            successCount++;
        } catch (e) {
            print("Failed to upload ${file.name}: $e");
        }
    }

    setState(() {
      _isUploading = false;
      if (successCount > 0) {
        _selectedFiles.clear(); // Clear list on success
        _selectedSubjectCode = null; // Reset subject
      }
    });

    if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully uploaded $successCount files!'), backgroundColor: AppTheme.successColor)
        );
    } else {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload files'), backgroundColor: AppTheme.errorColor)
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload E-Books'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    // Header
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                        ),
                        child: Column(
                            children: [
                                const Icon(Icons.cloud_upload_outlined, size: 48, color: AppTheme.primaryColor),
                                const SizedBox(height: 12),
                                Text(
                                    'Upload Study Materials',
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                    'Select a subject and add files (PDF, Images)',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                            ],
                        ),
                    ),
                    const SizedBox(height: 24),

                    // Label: Select Subject
                    Text('Select Subject', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),

                    // Dropdown
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                            color: AppTheme.bgCardLight,
                            borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedSubjectCode,
                                hint: const Text('Choose a subject'),
                                dropdownColor: AppTheme.bgCard,
                                items: _uniqueSubjects.map((s) {
                                    return DropdownMenuItem<String>(
                                        value: s['code'],
                                        child: Text('${s['name']} (${s['code']})', style: const TextStyle(color: AppTheme.textPrimary)),
                                    );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedSubjectCode = val),
                            ),
                        ),
                    ),
                    const SizedBox(height: 24),

                    // Upload File Section
                    Text('Upload File', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),

                    GestureDetector(
                        onTap: _pickFiles,
                        child: Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                                color: AppTheme.bgCardLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Row(
                                children: [
                                    const Icon(Icons.attach_file, color: AppTheme.textSecondary),
                                    const SizedBox(height: 12),
                                    Text(
                                        'Choose PDF / Images',
                                        style: TextStyle(color: AppTheme.textSecondary),
                                    ),
                                    const Spacer(),
                                    Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                            color: AppTheme.bgCard,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.borderColor),
                                        ),
                                        child: const Text('Browse', style: TextStyle(fontSize: 12)),
                                    ),
                                ],
                            ),
                        ),
                    ),
                    
                    if (_selectedFiles.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('(Add more files allowed)', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        const SizedBox(height: 8),
                        
                        // File List
                        ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _selectedFiles.length,
                            itemBuilder: (context, index) {
                                final file = _selectedFiles[index];
                                return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: AppTheme.bgCard,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppTheme.borderColor),
                                    ),
                                    child: Row(
                                        children: [
                                            Icon(
                                                file.extension == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                                                color: file.extension == 'pdf' ? Colors.red : Colors.blue,
                                                size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: Text(
                                                    file.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(color: AppTheme.textPrimary),
                                                ),
                                            ),
                                            IconButton(
                                                icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                                                onPressed: () => setState(() => _selectedFiles.removeAt(index)),
                                            ),
                                        ],
                                    ),
                                );
                            },
                        ),
                    ],

                    const SizedBox(height: 32),
                    
                    // Upload Button
                    SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                            onPressed: (_isUploading || _selectedSubjectCode == null || _selectedFiles.isEmpty) 
                                ? null 
                                : _uploadFiles,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isUploading 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Upload', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                    ),
                ],
              ),
            ),
    );
  }
}
