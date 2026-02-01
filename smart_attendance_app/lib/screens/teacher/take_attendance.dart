import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class TakeAttendanceScreen extends StatefulWidget {
  const TakeAttendanceScreen({super.key});

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  final _apiService = ApiService();
  final _picker = ImagePicker();
  
  List<dynamic> _classes = [];
  String? _selectedClassId;
  String? _selectedSubject;
  int _selectedPeriod = 1;
  DateTime _selectedDate = DateTime.now();
  File? _selectedImage;
  bool _isLoading = false;
  bool _isProcessing = false;
  bool _isSaving = false;
  Map<String, dynamic>? _result;
  // Editable attendance list - stores {reg_no, name, status} for each student
  List<Map<String, dynamic>> _editableAttendance = [];
  String? _error;

  List<dynamic> _todayTimetable = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    try {
      // Load FULL timetable instead of today's
      final data = await _apiService.getTeacherTimetable();
      if (mounted) {
        setState(() => _todayTimetable = data);
        // Auto-select based on current selection
        _autoSelectClass(_selectedPeriod);
      }
    } catch (e) {
      print('Failed to load timetable: $e');
    }
  }

  void _autoSelectClass(int period) {
    if (_todayTimetable.isEmpty) return;

    // Determine the day name for the selected date
    final dayName = DateFormat('EEE').format(_selectedDate); // e.g., "Mon", "Tue"
    final dayNameFull = DateFormat('EEEE').format(_selectedDate); // e.g., "Monday"

    print("AutoSelect: Checking for Period $period on $dayName/$dayNameFull");
    
    // Filter entry for this period AND Day
    final entry = _todayTimetable.firstWhere(
      (t) {
        final tDay = t['day']?.toString() ?? "";
        // Match day AND period
        return t['period'] == period && (tDay == dayName || tDay == dayNameFull);
      },
      orElse: () => null,
    );
    
    if (entry != null) {
      final classId = entry['class_id'];
      final subjectCode = entry['subject_code'];
      
      // Check if this class is in our list
      final exists = _classes.any((c) {
        return c['class_id'] == classId && c['subject_code'] == subjectCode;
      });
      
      if (exists) {
        setState(() {
          _selectedClassId = classId;
          _selectedSubject = subjectCode;
        });
        
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-selected Class $classId (${entry['subject_name'] ?? subjectCode})'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadClasses() async {
    try {
      setState(() => _isLoading = true);
      final classes = await _apiService.getTeacherClasses();
      setState(() {
        _classes = classes;
        _isLoading = false;
      });
      // Try auto-select again in case timetable loaded first
      if (_todayTimetable.isNotEmpty && mounted) {
         _autoSelectClass(_selectedPeriod);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load classes';
        _isLoading = false;
      });
    }
  }

  // removed _checkTimetable and _getPeriodFromTime

  Future<void> _pickImage(ImageSource source) async {
    // ... existing _pickImage code ...
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }



  Future<void> _processAttendance() async {
    if (_selectedClassId == null || _selectedSubject == null || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select class, subject, and capture an image')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await _apiService.markAttendance(
        classId: _selectedClassId!,
        subjectCode: _selectedSubject!,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        periodNo: _selectedPeriod,
        imageFile: _selectedImage!,
      );
      
      // Build editable list from all status arrays
      final presentList = (result['present'] as List<dynamic>?) ?? [];
      final absentList = (result['absent'] as List<dynamic>?) ?? [];
      final odList = (result['od'] as List<dynamic>?) ?? [];
      final mlList = (result['ml'] as List<dynamic>?) ?? [];
      
      final editableList = <Map<String, dynamic>>[];
      
      for (var regNo in presentList) {
        editableList.add({'reg_no': regNo.toString(), 'name': regNo.toString(), 'status': 'P'});
      }
      for (var regNo in absentList) {
        editableList.add({'reg_no': regNo.toString(), 'name': regNo.toString(), 'status': 'A'});
      }
      for (var regNo in odList) {
        editableList.add({'reg_no': regNo.toString(), 'name': regNo.toString(), 'status': 'OD'});
      }
      for (var regNo in mlList) {
        editableList.add({'reg_no': regNo.toString(), 'name': regNo.toString(), 'status': 'ML'});
      }
      
      // Sort by register number for cleaner view
      editableList.sort((a, b) => (a['reg_no'] as String).compareTo(b['reg_no'] as String));
      
      setState(() {
        _result = result;
        _editableAttendance = editableList;
        _isProcessing = false;
      });
    } catch (e) {
      // ... existing error handling ...
      print('DEBUG ERROR: $e'); // Add this log
      if (e is DioException) {
        print('DEBUG RESPONSE: ${e.response?.data}'); // Add this log
      }
      
      String errorMessage = 'Failed to process attendance';
      if (e is DioException && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map && data.containsKey('detail')) {
          final detail = data['detail'];
          if (detail is String) {
            errorMessage = detail;
          } else {
            errorMessage = detail.toString();
          }
        } else {
            errorMessage = e.message ?? errorMessage;
        }
      } else {
        errorMessage = e.toString();
      }

      setState(() {
        _error = errorMessage;
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Attendance'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _result != null
              ? _buildResultView()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Class Selection
                      Text('Select Class', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCardLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: (_selectedClassId != null && _selectedSubject != null)
                                ? (() {
                                    final idx = _classes.indexWhere((c) => c['class_id'] == _selectedClassId && c['subject_code'] == _selectedSubject);
                                    return idx >= 0 ? idx : null;
                                  })()
                                : null,
                            hint: const Text('Choose a class', style: TextStyle(color: AppTheme.textMuted)),
                            dropdownColor: AppTheme.bgCard,
                            items: List.generate(_classes.length, (index) {
                              final c = _classes[index];
                              return DropdownMenuItem<int>(
                                value: index,
                                child: Text('Class ${c['class_id']} - ${c['subject_name'] ?? c['subject_code']}', style: const TextStyle(color: AppTheme.textPrimary)),
                              );
                            }),
                            onChanged: (index) {
                              if (index != null) {
                                final selected = _classes[index];
                                setState(() {
                                  _selectedClassId = selected['class_id'];
                                  _selectedSubject = selected['subject_code'];
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Period Selection
                      Text('Period', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: List.generate(7, (i) {
                          final period = i + 1;
                          final isSelected = _selectedPeriod == period;
                          return GestureDetector(
                            onTap: () {
                                setState(() => _selectedPeriod = period);
                                _autoSelectClass(period);
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryColor : AppTheme.bgCardLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'P$period',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),

                      // Date Selection
                      Text('Date', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 7)),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
                            _autoSelectClass(_selectedPeriod); // Trigger auto-sync on date change
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCardLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate),
                                style: const TextStyle(color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Image Capture
                      Text('Capture Image', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 12),
                      if (_selectedImage != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(_selectedImage!, height: 200, width: double.infinity, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.errorColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _pickImage(ImageSource.camera),
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                                  ),
                                  child: const Column(
                                    children: [
                                      Icon(Icons.camera_alt, size: 40, color: AppTheme.primaryColor),
                                      SizedBox(height: 8),
                                      Text('Camera', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _pickImage(ImageSource.gallery),
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.3)),
                                  ),
                                  child: const Column(
                                    children: [
                                      Icon(Icons.photo_library, size: 40, color: AppTheme.secondaryColor),
                                      SizedBox(height: 8),
                                      Text('Gallery', style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 32),

                      // Process Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _processAttendance,
                          child: _isProcessing
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                    SizedBox(width: 12),
                                    Text('Processing with AI...'),
                                  ],
                                )
                              : const Text('Mark Attendance'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildResultView() {
    final sessionId = _result?['session_id'] as int?;
    final presentCount = _editableAttendance.where((s) => s['status'] == 'P').length;
    final totalCount = _editableAttendance.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Success Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle, size: 64, color: Colors.white),
                const SizedBox(height: 16),
                Text('Attendance Marked!', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text('$presentCount / $totalCount students present', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16)),
                const SizedBox(height: 8),
                Text('Tap on a student to toggle status', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Student List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Students Detected', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              Text('Tap to edit', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Editable Student List
          ...List.generate(_editableAttendance.length, (index) {
            final s = _editableAttendance[index];
            final status = s['status'];
            
            Color color;
            IconData icon;
            String text;
            
            switch (status) {
              case 'P':
                color = AppTheme.successColor;
                icon = Icons.check_circle;
                text = 'Present';
                break;
              case 'A':
                color = AppTheme.errorColor;
                icon = Icons.cancel;
                text = 'Absent';
                break;
              case 'OD':
                color = Colors.blue;
                icon = Icons.work;
                text = 'On Duty';
                break;
              case 'ML':
                color = Colors.orange;
                icon = Icons.local_hospital;
                text = 'Medical Leave';
                break;
              default:
                color = AppTheme.textMuted;
                icon = Icons.help_outline;
                text = '-';
            }

            return GestureDetector(
              onTap: () {
                setState(() {
                  // Cycle statuses: P -> A -> OD -> ML -> P
                  if (status == 'P') _editableAttendance[index]['status'] = 'A';
                  else if (status == 'A') _editableAttendance[index]['status'] = 'OD';
                  else if (status == 'OD') _editableAttendance[index]['status'] = 'ML';
                  else _editableAttendance[index]['status'] = 'P';
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withOpacity(0.2),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['name'] ?? 'Unknown', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                          Text(s['reg_no'] ?? '', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        text,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),

          // Save Changes Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () => _saveChanges(sessionId),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 12),
                        Text('Saving Changes...'),
                      ],
                    )
                  : const Text('Save Changes'),
            ),
          ),
          const SizedBox(height: 12),

          // Back Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Home'),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _saveChanges(int? sessionId) async {
    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No session to update')),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final updates = _editableAttendance.map((s) => {
        'reg_no': s['reg_no'],
        'status': s['status'],
      }).toList();
      
      await _apiService.updateAttendanceRecords(sessionId: sessionId, updates: updates);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

