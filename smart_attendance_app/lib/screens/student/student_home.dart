import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';
import 'weekly_attendance.dart';
import 'raise_request.dart';
import 'student_ebook_home.dart';
import 'student_tasks_home.dart';
import '../timetable_screen.dart';
import '../timetable_screen.dart';
import 'student_marks_screen.dart';
import 'final_marksheet_screen.dart';
import 'my_profile_screen.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  final _apiService = ApiService();
  Map<String, dynamic>? _todayData;
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
      final today = await _apiService.getTodayAttendance();
      final weekly = await _apiService.getWeeklyStudentAttendance();
      setState(() {
        _todayData = today;
        _weeklyData = weekly;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await _apiService.logout();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.bgCard,
                  title: const Text('Logout', style: TextStyle(color: AppTheme.textPrimary)),
                  content: const Text('Are you sure?', style: TextStyle(color: AppTheme.textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    TextButton(onPressed: () { Navigator.pop(ctx); _logout(); }, child: const Text('Logout', style: TextStyle(color: AppTheme.errorColor))),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                        const SizedBox(height: 16),
                        Text('Failed to load data', style: TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Overall Attendance Card
                          _buildOverallCard(),
                          const SizedBox(height: 20),
                          
                          // Today's Attendance
                          _buildSectionTitle("Today's Attendance"),
                          const SizedBox(height: 12),
                          _buildTodayGrid(),
                          const SizedBox(height: 24),
                          
                          // Quick Actions
                          _buildSectionTitle("Quick Actions"),
                          const SizedBox(height: 12),
                          _buildActionCard(
                            title: 'Weekly Attendance',
                            icon: Icons.calendar_view_week,
                            color: Colors.blue,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyAttendanceScreen())),
                          ),
                          const SizedBox(height: 12),
                          _buildActionCard(
                            title: 'My Profile',
                            icon: Icons.person,
                            color: Colors.pink,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen())),
                          ),
                          const SizedBox(height: 12),
                          _buildActionCard(
                            title: 'View Timetable',
                            icon: Icons.schedule,
                            color: Colors.purple,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetableScreen(userRole: 'student'))),
                          ),
                          const SizedBox(height: 12),
                          _buildActionCard(
                            title: 'Raise OD/ML Request',
                            icon: Icons.note_add,
                            color: Colors.orange,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RaiseRequestScreen())),
                          ),
                          const SizedBox(height: 12),
                          _buildActionCard(
                            title: 'Homework / Assignments',
                            icon: Icons.assignment,
                            color: Colors.teal,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentTasksHome())),
                          ),
                          const SizedBox(height: 12),
                          _buildActionCard(
                            title: 'Study Materials / E-Books',
                            icon: Icons.menu_book_rounded,
                            color: Colors.indigo,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentEBookHomeScreen())),
                          ),
                          const SizedBox(height: 12),
                          _buildActionCard(
                            title: 'My Marks / Reports',
                            icon: Icons.grade,
                            color: Colors.purpleAccent,
                            onTap: () async {
                              // Need to fetch subjects to pass them
                              final api = ApiService();
                              final subjects = await api.getStudentSubjects(); // Reuse Ebook Method? Or Timetable?
                              // Actually reusing ebook method (student_materials) logic might be good or just fetch in screen.
                              // Let's pass subjects.
                              Navigator.push(context, MaterialPageRoute(builder: (_) => StudentMarksScreen(subjects: subjects)));
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildActionCard(
                            title: 'Semester Results',
                            icon: Icons.school,
                            color: Colors.redAccent,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinalMarksheetScreen())),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildActionCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.bgCardLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildOverallCard() {
    // ... existing _buildOverallCard code ...
    final percentage = _weeklyData?['percentage'] ?? _todayData?['overall_percentage'] ?? 0;
    final present = _weeklyData?['total_present'] ?? 0;
    final total = _weeklyData?['total_working'] ?? 0;
    final ml = _weeklyData?['total_ml'] ?? 0;
    
    // Risk Calculation Logic
    String statusText;
    Color statusColor;
    
    if (percentage >= 75) {
      statusText = '✓ Good Standing';
      statusColor = AppTheme.successColor;
    } else {
      // Check if ML helps cross 75%
      final potentialPresent = present + ml;
      final potentialPercentage = (total > 0) ? (potentialPresent / total * 100) : 0;
      
      if (potentialPercentage >= 75) {
        statusText = '⚠ Condonation Safe (ML)';
        statusColor = Colors.orange;
      } else {
        statusText = '☠ Critical / Risk';
        statusColor = AppTheme.errorColor;
      }
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Weekly Attendance',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$percentage%',
            style: GoogleFonts.inter(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$present / $total classes ($ml ML)',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: TextStyle(color: statusColor == AppTheme.successColor ? Colors.white : (statusColor == Colors.orange ? Colors.yellowAccent : Colors.redAccent), fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayGrid() {
    // ... existing _buildTodayGrid code (keep as is) ...
    final periods = (_todayData?['periods'] as List?) ?? [];
    
    if (periods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_available, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              Text('No attendance data for today', style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLight,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: List.generate(7, (index) => Expanded(
                child: Center(
                  child: Text(
                    'P${index + 1}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              )),
            ),
          ),
          // Status row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: List.generate(7, (index) {
                final period = periods.length > index ? periods[index] : null;
                final status = period?['status'] ?? 'not_taken';
                String badgeText = '-';
                if (status == 'present' || status == 'P') badgeText = 'P';
                else if (status == 'absent' || status == 'A') badgeText = 'A';
                else if (status == 'od' || status == 'OD') badgeText = 'OD';
                else if (status == 'medical_leave' || status == 'ML') badgeText = 'ML';
                
                return Expanded(
                  child: Center(
                    child: _buildStatusBadge(badgeText),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
     // ... existing badge code ...
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
