import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class WeeklyAttendanceScreen extends StatefulWidget {
  const WeeklyAttendanceScreen({super.key});

  @override
  State<WeeklyAttendanceScreen> createState() => _WeeklyAttendanceScreenState();
}

class _WeeklyAttendanceScreenState extends State<WeeklyAttendanceScreen> {
  final _apiService = ApiService();
  Map<String, dynamic>? _weeklyData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final data = await _apiService.getWeeklyStudentAttendance();
      setState(() {
        _weeklyData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Attendance')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildWeeklyGrid(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildWeeklyGrid() {
    final rows = (_weeklyData?['rows'] as List?) ?? [];
    final percentage = _weeklyData?['percentage'] ?? 0;

    if (rows.isEmpty) {
      return const Center(child: Text('No attendance data available'));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text('Date',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppTheme.textPrimary)),
                ),
                ...List.generate(
                    7,
                    (index) => Expanded(
                          child: Center(
                            child: Text('P${index + 1}',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: AppTheme.textPrimary)),
                          ),
                        )),
              ],
            ),
          ),

          // Data rows
          ...rows.map((row) => _buildWeeklyRow(row)),

          // Footer with percentage
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Attendance % : ',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: percentage >= 75
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$percentage%',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyRow(Map<String, dynamic> row) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.bgCardLight, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              row['date'] ?? '',
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(child: Center(child: _buildStatusBadge(row['p1'] ?? '-'))),
          Expanded(child: Center(child: _buildStatusBadge(row['p2'] ?? '-'))),
          Expanded(child: Center(child: _buildStatusBadge(row['p3'] ?? '-'))),
          Expanded(child: Center(child: _buildStatusBadge(row['p4'] ?? '-'))),
          Expanded(child: Center(child: _buildStatusBadge(row['p5'] ?? '-'))),
          Expanded(child: Center(child: _buildStatusBadge(row['p6'] ?? '-'))),
          Expanded(child: Center(child: _buildStatusBadge(row['p7'] ?? '-'))),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'P':
      case 'present':
        bgColor = AppTheme.successColor.withOpacity(0.2);
        textColor = AppTheme.successColor;
        break;
      case 'A':
      case 'absent':
        bgColor = AppTheme.errorColor.withOpacity(0.2);
        textColor = AppTheme.errorColor;
        break;
      case 'OD':
      case 'od':
        bgColor = Colors.blue.withOpacity(0.2);
        textColor = Colors.blue;
        break;
      case 'ML':
      case 'medical_leave':
        bgColor = Colors.orange.withOpacity(0.2);
        textColor = Colors.orange;
        break;
      default:
        bgColor = AppTheme.bgCardLight;
        textColor = AppTheme.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: textColor,
        ),
      ),
    );
  }
}
