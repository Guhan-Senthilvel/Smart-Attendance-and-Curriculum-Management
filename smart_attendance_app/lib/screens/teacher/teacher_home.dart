import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';
import 'take_attendance.dart';
import 'manual_attendance.dart';
import 'view_attendance.dart';
import 'teacher_inbox.dart';
import 'upload_ebook_screen.dart';
import 'create_task_screen.dart';
import 'view_submissions_screen.dart';
import '../timetable_screen.dart';
import 'marks_entry_screen.dart';
import 'display_marks_screen.dart';
import 'marks_statistics_screen.dart';
import 'student_profile_lookup_screen.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  final _apiService = ApiService();
  
  Future<void> _logout() async {
    await _apiService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.bgCard,
                  title: const Text('Logout', style: TextStyle(color: AppTheme.textPrimary)),
                  content: const Text('Are you sure you want to logout?', style: TextStyle(color: AppTheme.textSecondary)),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.waving_hand, size: 28, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome Back!',
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ready to mark attendance?',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Quick Actions Title
              Text(
                'Quick Actions',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              
              // Action Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1,
                children: [
                  ActionButton(
                    icon: Icons.camera_alt,
                    label: 'AI Attendance',
                    color: AppTheme.primaryColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TakeAttendanceScreen())),
                  ),
                  ActionButton(
                    icon: Icons.edit_note,
                    label: 'Manual\nAttendance',
                    color: AppTheme.secondaryColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualAttendanceScreen())),
                  ),
                  ActionButton(
                    icon: Icons.history,
                    label: 'Weekly\nAttendance',
                    color: AppTheme.accentColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewAttendanceScreen())),
                  ),
                  ActionButton(
                    icon: Icons.inbox,
                    label: 'Inbox',
                    color: AppTheme.warningColor,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherInboxScreen()));
                    },
                  ),
                  ActionButton(
                    icon: Icons.calendar_month,
                    label: 'My\nTimetable',
                    color: Colors.teal,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetableScreen(userRole: 'teacher'))),
                  ),
                  ActionButton(
                     icon: Icons.cloud_upload,
                     label: 'Upload\nE-Books',
                     color: Colors.indigo,
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadEBookScreen())),
                  ),
                  ActionButton(
                     icon: Icons.assignment_add,
                     label: 'Task\nAssigner',
                     color: Colors.pink,
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTaskScreen())),
                  ),
                  ActionButton(
                     icon: Icons.assignment_turned_in,
                     label: 'View\nSubmissions',
                     color: Colors.deepOrange,
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewSubmissionsScreen())),
                  ),
                  ActionButton(
                     icon: Icons.grade,
                     label: 'Marks\nEntry',
                     color: Colors.purple,
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarksEntryScreen())),
                  ),
                  ActionButton(
                     icon: Icons.summarize,
                     label: 'Display\nMarks',
                     color: Colors.blueGrey,
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DisplayMarksScreen())),
                  ),
                  ActionButton(
                     icon: Icons.bar_chart,
                     label: 'Marks\nStatistics',
                     color: Colors.teal,
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarksStatisticsScreen())),
                  ),
                  ActionButton(
                     icon: Icons.person_search,
                     label: 'Student\nProfiles',
                     color: Colors.deepPurpleAccent,
                     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentProfileLookupScreen())),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Today's Stats Card
              GradientCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppTheme.accentColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Today's Schedule",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap on AI Attendance to get started with marking attendance using face recognition.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
