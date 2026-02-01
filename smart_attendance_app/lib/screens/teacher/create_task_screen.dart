import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  bool _isLoading = false;
  List<dynamic> _classes = [];
  Map<String, dynamic>? _selectedClass;
  String _taskType = 'Daily'; // Daily, Assignment
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _deadlineController = TextEditingController();
  final _maxMarksController = TextEditingController(text: '10');
  
  DateTime? _selectedDeadline;
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }
  
  Future<void> _loadClasses() async {
    try {
      final classes = await _apiService.getTeacherClasses();
      setState(() {
        _classes = classes;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load classes: $e')));
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'doc', 'docx'],
    );
    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 23, minute: 59),
      );
      if (time != null) {
        setState(() {
          _selectedDeadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          _deadlineController.text = _selectedDeadline.toString().split('.')[0];
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedClass == null) {
      if (_selectedClass == null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a class/subject')));
      return;
    }

    setState(() => _isLoading = true);
    
    // Auto deadline for Daily Work (24 hours) if not set
    DateTime? finalDeadline = _selectedDeadline;
    if (_taskType == 'Daily' && finalDeadline == null) {
        finalDeadline = DateTime.now().add(const Duration(hours: 24));
    }

    try {
      await _apiService.createTask(
        classId: _selectedClass!['class_id'],
        subjectCode: _selectedClass!['subject_code'],
        type: _taskType,
        title: _titleController.text,
        description: _descriptionController.text,
        deadline: finalDeadline,
        maxMarks: int.tryParse(_maxMarksController.text) ?? 10,
        file: _selectedFile,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work Created Successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Work')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text('Create New Task', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 20),
              
              // 1. Select Class/Subject
              DropdownButtonFormField<Map<String, dynamic>>(
                isExpanded: true, 
                decoration: const InputDecoration(labelText: 'Select Class & Subject'),
                value: _selectedClass,
                items: _classes.map((c) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: c,
                    child: Text(
                      '${c['subject_name']} (${c['subject_code']}) - Class ${c['class_id']}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedClass = val),
              ),
              const SizedBox(height: 16),
              
              // 2. Type
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Type'),
                value: _taskType,
                items: ['Daily', 'Assignment'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) {
                    setState(() {
                         _taskType = val!;
                         if (_taskType == 'Daily') {
                             _deadlineController.clear();
                             _selectedDeadline = null;
                         }
                    });
                },
              ),
              const SizedBox(height: 16),
              
              // 3. Title & Description
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g., Normalization Problems'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description', hintText: 'Solve Q1-Q5...'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              
              // 4. Deadline
              if (_taskType == 'Assignment') ...[
                  TextFormField(
                    controller: _deadlineController,
                    decoration: InputDecoration(
                      labelText: 'Deadline',
                      suffixIcon: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _selectDeadline),
                    ),
                    readOnly: true,
                    onTap: _selectDeadline,
                    validator: (v) => v!.isEmpty ? 'Required for Assignments' : null,
                  ),
                  const SizedBox(height: 16),
              ],
              if (_taskType == 'Daily')
                  Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text('Note: Daily work automatically expires in 24 hours.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  ),

              
              // 5. Marks
              TextFormField(
                controller: _maxMarksController,
                decoration: const InputDecoration(labelText: 'Max Marks'),
                keyboardType: TextInputType.number,
                 validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              // 6. Attachment
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCardLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Text(
                        _selectedFile != null ? _selectedFile!.path.split('/').last : 'No file attached',
                        style: TextStyle(color: _selectedFile != null ? AppTheme.textPrimary : AppTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Attach'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Publish Work'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
