import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class TimetableScreen extends StatefulWidget {
  final String userRole; // 'student' or 'teacher'

  const TimetableScreen({super.key, required this.userRole});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  bool _isLoading = true;
  List<dynamic> _timetable = [];
  final List<String> _days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  final List<int> _periods = [1, 2, 3, 4, 5, 6, 7];

  @override
  void initState() {
    super.initState();
    // Force Landscape for better view
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadTimetable();
  }

  @override
  void dispose() {
    // Restore Portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  Future<void> _loadTimetable() async {
    try {
      final data = widget.userRole == 'student'
          ? await ApiService().getStudentTimetable()
          : await ApiService().getTeacherTimetable();
      setState(() {
        _timetable = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load timetable: $e')),
        );
      }
    }
  }

  Map<String, dynamic>? _getCell(String day, int period) {
    try {
      return _timetable.firstWhere(
        (t) => t['day'] == day && t['period'] == period,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Weekly Timetable'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Table(
                      defaultColumnWidth: const FixedColumnWidth(120.0),
                      border: TableBorder.all(
                        color: Colors.white24,
                        width: 1,
                      ),
                      children: [
                        // Header Row (Periods)
                        TableRow(
                          decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.2)),
                          children: [
                            const TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text('Day', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                            ..._periods.map((p) => TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Center(child: Text('P$p', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                                  ),
                                )),
                          ],
                        ),
                        // Data Rows (Days)
                        ..._days.map((day) => TableRow(
                              children: [
                                TableCell(
                                  child: Container(
                                    color: AppTheme.bgCard,
                                    padding: const EdgeInsets.all(12.0),
                                    child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                                  ),
                                ),
                                ..._periods.map((period) {
                                  final entry = _getCell(day, period);
                                  return TableCell(
                                    child: Container(
                                      padding: const EdgeInsets.all(8.0),
                                      height: 80, // Fixed height for consistency
                                      child: entry != null
                                          ? _buildCellContent(entry)
                                          : const Center(child: Text('-', style: TextStyle(color: Colors.white24))),
                                    ),
                                  );
                                }),
                              ],
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCellContent(Map<String, dynamic> entry) {
    if (widget.userRole == 'student') {
      // Student View: Subject + Teacher Name
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            entry['subject_code'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            entry['teacher_name'] ?? 'Unknown',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else {
      // Teacher View: Class + Subject
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Class ${entry['class_id']}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            entry['subject_code'] ?? '',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
  }
}
