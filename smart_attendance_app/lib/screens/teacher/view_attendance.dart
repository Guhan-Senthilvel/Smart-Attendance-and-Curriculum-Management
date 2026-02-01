import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';

class ViewAttendanceScreen extends StatefulWidget {
  const ViewAttendanceScreen({super.key});

  @override
  State<ViewAttendanceScreen> createState() => _ViewAttendanceScreenState();
}

class _ViewAttendanceScreenState extends State<ViewAttendanceScreen> {
  final _apiService = ApiService();
  
  List<dynamic> _classes = [];
  String? _selectedClassId;
  String? _selectedSubject;
  Map<String, dynamic>? _weeklyData;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isSaving = false;
  
  // Editable data for the grid
  Map<String, Map<String, String>> _editableStatuses = {}; // reg_no -> {session_key -> status}

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      setState(() => _isLoading = true);
      final classes = await _apiService.getTeacherClasses();
      setState(() {
        _classes = classes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWeeklyData() async {
    if (_selectedClassId == null || _selectedSubject == null) return;
    try {
      setState(() => _isLoading = true);
      final data = await _apiService.getWeeklyAttendance(
        classId: _selectedClassId!,
        subjectCode: _selectedSubject!,
      );
      
      // Build editable statuses map
      final editableMap = <String, Map<String, String>>{};
      for (var student in (data['students'] as List? ?? [])) {
        final regNo = student['reg_no'] as String;
        final attendance = student['attendance'] as Map<String, dynamic>? ?? {};
        editableMap[regNo] = {};
        for (var entry in attendance.entries) {
          editableMap[regNo]![entry.key] = (entry.value['status'] as String?) ?? '-';
        }
      }
      
      setState(() {
        _weeklyData = data;
        _editableStatuses = editableMap;
        _isLoading = false;
        _isEditing = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }

  Future<void> _showProofImage(int? sessionId) async {
    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No proof image for this session')),
      );
      return;
    }
    
    final url = await _apiService.getProofImageUrlWithAuth(sessionId);
    if (url == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Proof Image'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            SizedBox(
              height: 500,
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 8.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, stack) => Container(
                    height: 200,
                    color: AppTheme.bgCard,
                    child: const Center(child: Text('Failed to load image', style: TextStyle(color: AppTheme.textMuted))),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Attendance Data')),
      body: Column(
        children: [
          // Class Selector
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
                      hint: const Text('Select Class & Subject', style: TextStyle(color: AppTheme.textMuted)),
                      dropdownColor: AppTheme.bgCard,
                      items: List.generate(_classes.length, (index) {
                        final c = _classes[index];
                        return DropdownMenuItem<int>(
                        value: index,
                        child: Text(
                          'Class ${c['class_id']} - ${c['subject_name'] ?? c['subject_code']}',
                          style: GoogleFonts.inter(color: AppTheme.textPrimary),
                        ),
                      );
                      }),
                      onChanged: (index) {
                        if (index != null) {
                          setState(() {
                            _selectedClassId = _classes[index]['class_id'];
                            _selectedSubject = _classes[index]['subject_code'];
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Load Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loadWeeklyData,
                    child: const Text('Load Attendance'),
                  ),
                ),
              ],
            ),
          ),

          // Weekly Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _weeklyData == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month, size: 64, color: AppTheme.textMuted),
                            const SizedBox(height: 16),
                            Text('Select class and tap Load', style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      )
                    : _buildWeeklyGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyGrid() {
    final sessions = (_weeklyData!['sessions'] as List<dynamic>?) ?? [];
    final students = (_weeklyData!['students'] as List<dynamic>?) ?? [];
    
    if (sessions.isEmpty) {
      return const Center(child: Text('No attendance sessions found for past 7 days', style: TextStyle(color: AppTheme.textMuted)));
    }
    
    if (students.isEmpty) {
      return const Center(child: Text('No students found', style: TextStyle(color: AppTheme.textMuted)));
    }

    return Column(
      children: [
        // Header row
        Container(
          color: AppTheme.bgCard,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text('STUDENT ATTENDANCE RECORD', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
            ],
          ),
        ),
        
        // Table with Nested Scrolling (Vertical -> Horizontal)
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.grey[800]),
                child: DataTable(
                  columnSpacing: 20,
                  headingRowHeight: 60,
                  dataRowMinHeight: 50,
                  dataRowMaxHeight: 50,
                  headingRowColor: WidgetStateProperty.all(AppTheme.bgCardLight),
                  border: TableBorder.all(color: Colors.grey[800]!, width: 1),
                  columns: [
                    const DataColumn(label: SizedBox(width: 120, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 14)))),
                    const DataColumn(label: SizedBox(width: 100, child: Text('Reg No', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 14)))),
                    ...sessions.map((s) => DataColumn(
                      label: SizedBox(
                        width: 80,
                        child: GestureDetector(
                          onTap: () => _showProofImage(s['session_id']),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(s['key'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 12)),
                              const SizedBox(height: 4),
                              const Icon(Icons.image, size: 14, color: AppTheme.primaryColor),
                            ],
                          ),
                        ),
                      ),
                    )),
                    const DataColumn(label: SizedBox(width: 50, child: Text('%', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 14)))),
                  ],
                  rows: students.map<DataRow>((student) {
                    final regNo = student['reg_no'] as String;
                    final name = student['name'] as String;
                    final percentage = (student['percentage'] as num?) ?? 0;
                    
                    return DataRow(
                      cells: [
                        DataCell(SizedBox(width: 120, child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)))),
                        DataCell(SizedBox(width: 100, child: Text(regNo, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)))),
                        ...sessions.map((s) {
                          final sessionKey = s['key'] as String;
                          final status = _editableStatuses[regNo]?[sessionKey] ?? '-';
                          return DataCell(
                            GestureDetector(
                              onTap: _isEditing ? () => _toggleStatus(regNo, sessionKey) : null,
                              child: Container(
                                width: 80,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                color: Colors.transparent, // Hit test target
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: status == 'P' ? AppTheme.successColor.withOpacity(0.2) 
                                         : status == 'A' ? AppTheme.errorColor.withOpacity(0.2) 
                                         : status == 'OD' ? Colors.blue.withOpacity(0.2)
                                         : status == 'ML' ? Colors.orange.withOpacity(0.2)
                                         : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: status == '-' ? Border.all(color: Colors.grey[700]!) : null,
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: status == 'P' ? AppTheme.successColor 
                                           : status == 'A' ? AppTheme.errorColor 
                                           : status == 'OD' ? Colors.blue
                                           : status == 'ML' ? Colors.orange
                                           : AppTheme.textMuted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        DataCell(
                          Container(
                            width: 50,
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: percentage >= 75 ? AppTheme.successColor : AppTheme.warningColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('${percentage.round()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.bgCard,
            child: Column(
              children: [
                // View Proof Images Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showProofImagesDialog(),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('View Proof Images (7 days)'),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Edit/Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _toggleEditMode,
                    icon: Icon(_isEditing ? Icons.save : Icons.edit),
                    label: Text(_isEditing ? (_isSaving ? 'Saving...' : 'Save Changes') : 'Edit Attendance'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  
    void _toggleStatus(String regNo, String sessionKey) {
      final current = _editableStatuses[regNo]?[sessionKey] ?? '-';
      setState(() {
        if (current == 'P') {
          _editableStatuses[regNo]![sessionKey] = 'A';
        } else if (current == 'A') {
          _editableStatuses[regNo]![sessionKey] = 'OD';
        } else if (current == 'OD') {
          _editableStatuses[regNo]![sessionKey] = 'ML';
        } else if (current == 'ML') {
          _editableStatuses[regNo]![sessionKey] = 'P';
        } else {
          // If unassigned or '-', start with P
          _editableStatuses[regNo]![sessionKey] = 'P';
        }
      });
    }

  Future<void> _toggleEditMode() async {
    if (_isEditing) {
      await _saveAllChanges();
    } else {
      setState(() => _isEditing = true);
    }
  }

  Future<void> _saveAllChanges() async {
    if (_weeklyData == null) return;
    
    setState(() => _isSaving = true);
    
    try {
      final sessions = (_weeklyData!['sessions'] as List<dynamic>?) ?? [];
      final students = (_weeklyData!['students'] as List<dynamic>?) ?? [];
      
      // Group updates by session
      for (var session in sessions) {
        final sessionKey = session['key'] as String;
        final sessionId = session['session_id'] as int;
        
        final updates = <Map<String, dynamic>>[];
        for (var student in students) {
          final regNo = student['reg_no'] as String;
          final newStatus = _editableStatuses[regNo]?[sessionKey];
          if (newStatus != null && newStatus != '-') {
            updates.add({'reg_no': regNo, 'status': newStatus});
          }
        }
        
        if (updates.isNotEmpty) {
          await _apiService.updateAttendanceRecords(sessionId: sessionId, updates: updates);
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved successfully!'), backgroundColor: Colors.green),
      );
      
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      
      // Reload to refresh percentages
      await _loadWeeklyData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isSaving = false);
    }
  }

  void _showProofImagesDialog() {
    if (_weeklyData == null) return;
    final sessions = (_weeklyData!['sessions'] as List<dynamic>?) ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Proof Images'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return ListTile(
                leading: Icon(Icons.image, color: AppTheme.primaryColor),
                title: Text(session['key']),
                subtitle: Text('Tap to view'),
                onTap: () {
                  Navigator.pop(context);
                  _showProofImage(session['session_id']);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
