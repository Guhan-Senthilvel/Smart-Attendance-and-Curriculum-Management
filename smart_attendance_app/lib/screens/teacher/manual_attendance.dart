import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class ManualAttendanceScreen extends StatefulWidget {
  const ManualAttendanceScreen({super.key});

  @override
  State<ManualAttendanceScreen> createState() => _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState extends State<ManualAttendanceScreen> {
  final _apiService = ApiService();
  
  List<dynamic> _classes = [];
  List<dynamic> _students = [];
  Map<String, String> _attendance = {}; // 'P', 'A', 'OD', 'ML'
  List<dynamic> _todayTimetable = [];
  
  int? _selectedClassNo; // Deprecated
  String? _selectedClassId;

  String? _selectedSubject;
  int _selectedPeriod = 1;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;

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
        // Auto-select based on current selection (default Period 1)
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
      final className = entry['subject_name'] ?? subjectCode;
      
      final exists = _classes.any((c) {
        final match = c['class_id'] == classId && c['subject_code'] == subjectCode;
        return match;
      });
      
      if (exists) {
        setState(() {
          _selectedClassId = classId;
          _selectedSubject = subjectCode;
        });
        // Important: Load students for the auto-selected class
        _loadStudents();
        
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-selected Class $classId ($className)'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudents() async {
    if (_selectedClassId == null) return;
    try {
      setState(() => _isLoading = true);
      final students = await _apiService.getClassStudents(_selectedClassId!);
      setState(() {
        _students = students;
        // Initialize all as present
        _attendance = {for (var s in students) s['reg_no']: "P"};
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAttendance() async {
    if (_selectedClassId == null || _selectedSubject == null) return;
    
    setState(() => _isSaving = true);
    
    try {
      final attendanceList = _students.map((s) => {
        'reg_no': s['reg_no'],
        'status': _attendance[s['reg_no']] ?? "P",
      }).toList();

      await _apiService.saveManualAttendance(
        classId: _selectedClassId!,
        subjectCode: _selectedSubject!,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
        periodNo: _selectedPeriod,
        attendanceList: attendanceList,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance saved successfully!'), backgroundColor: AppTheme.successColor),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      String errorMessage = 'Failed to save attendance';
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _markAllPresent() => setState(() => _attendance.updateAll((_, __) => "P"));
  void _markAllAbsent() => setState(() => _attendance.updateAll((_, __) => "A"));

  @override
  Widget build(BuildContext context) {
    final presentCount = _attendance.values.where((v) => v == "P" || v == "OD").length;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Attendance'),
        actions: [
          if (_students.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (val) {
                if (val == 'all_present') _markAllPresent();
                if (val == 'all_absent') _markAllAbsent();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'all_present', child: Text('Mark All Present')),
                const PopupMenuItem(value: 'all_absent', child: Text('Mark All Absent')),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Selection Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppTheme.bgCard,
                  child: Column(
                    children: [
                      // Class Dropdown
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
                            hint: const Text('Select Class', style: TextStyle(color: AppTheme.textMuted)),
                            dropdownColor: AppTheme.bgCard,
                            items: List.generate(_classes.length, (index) {
                              final c = _classes[index];
                              return DropdownMenuItem<int>(
                                value: index,
                                child: Text('Class ${c['class_id']} - ${c['subject_code']}', style: const TextStyle(color: AppTheme.textPrimary)),
                              );
                            }),
                            onChanged: (index) {
                              if (index != null) {
                                final selected = _classes[index];
                                setState(() {
                                  _selectedClassId = selected['class_id'];
                                  _selectedSubject = selected['subject_code'];
                                });
                                _loadStudents();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Period & Date Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.bgCardLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedPeriod,
                                  dropdownColor: AppTheme.bgCard,
                                  items: List.generate(7, (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text('Period ${i + 1}', style: const TextStyle(color: AppTheme.textPrimary)),
                                  )),
                                  onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedPeriod = val);
                                        _autoSelectClass(val);
                                      }
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 7)),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() => _selectedDate = date);
                                  _autoSelectClass(_selectedPeriod);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgCardLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryColor),
                                    const SizedBox(width: 8),
                                    Text(DateFormat('MMM dd').format(_selectedDate), style: const TextStyle(color: AppTheme.textPrimary)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Stats Bar
                if (_students.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgDark,
                      border: Border(bottom: BorderSide(color: AppTheme.bgCardLight)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_students.length} students', style: TextStyle(color: AppTheme.textSecondary)),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('$presentCount P', style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('${_students.length - presentCount} A', style: const TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Student List
                Expanded(
                  child: _students.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: AppTheme.textMuted),
                              const SizedBox(height: 16),
                              Text('Select a class to view students', style: TextStyle(color: AppTheme.textSecondary)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _students.length,
                          itemBuilder: (context, index) {
                            final student = _students[index];
                            final status = _attendance[student['reg_no']] ?? "P";
                            final isPresent = status == "P" || status == "OD";
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.bgCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isPresent 
                                      ? AppTheme.successColor.withOpacity(0.3) 
                                      : (status == "ML" ? Colors.orange.withOpacity(0.3) : AppTheme.errorColor.withOpacity(0.3)),
                                ),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isPresent 
                                      ? AppTheme.successColor.withOpacity(0.2) 
                                      : (status == "ML" ? Colors.orange.withOpacity(0.2) : AppTheme.errorColor.withOpacity(0.2)),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: isPresent 
                                          ? AppTheme.successColor 
                                          : (status == "ML" ? Colors.orange : AppTheme.errorColor),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                title: Text(student['name'] ?? 'Unknown', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                                subtitle: Text(student['reg_no'] ?? '', style: TextStyle(color: AppTheme.textSecondary)),
                                trailing: DropdownButton<String>(
                                  value: status,
                                  dropdownColor: AppTheme.bgCard,
                                  underline: Container(),
                                  items: const [
                                    DropdownMenuItem(value: "P", child: Text("Present", style: TextStyle(color: AppTheme.successColor))),
                                    DropdownMenuItem(value: "A", child: Text("Absent", style: TextStyle(color: AppTheme.errorColor))),
                                    DropdownMenuItem(value: "OD", child: Text("OD", style: TextStyle(color: Colors.blue))),
                                    DropdownMenuItem(value: "ML", child: Text("Med Leave", style: TextStyle(color: Colors.orange))),
                                  ],
                                  onChanged: (val) => setState(() => _attendance[student['reg_no']] = val!),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Save Button
                if (_students.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -5))],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveAttendance,
                        child: _isSaving
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                  SizedBox(width: 12),
                                  Text('Saving...'),
                                ],
                              )
                            : const Text('Save Attendance'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
