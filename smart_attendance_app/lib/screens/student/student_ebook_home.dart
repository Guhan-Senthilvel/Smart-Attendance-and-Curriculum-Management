import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import 'subject_materials_screen.dart';

class StudentEBookHomeScreen extends StatefulWidget {
  const StudentEBookHomeScreen({super.key});

  @override
  State<StudentEBookHomeScreen> createState() => _StudentEBookHomeScreenState();
}

class _StudentEBookHomeScreenState extends State<StudentEBookHomeScreen> {
  final _apiService = ApiService();
  List<dynamic> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      // Reusing getStudentTimetable is not ideal as it gives periods, not unique subjects.
      // But we don't have a direct "getEnrolledSubjects" endpoint yet?
      // Actually we can use `getStudentSubjectMap` or infer from timetable.
      // Let's use `getStudentTimetable` and unique-ify or better, check if we have a better endpoint.
      // Ah, ApiService doesn't expose getSubjects directly for students.
      // Workaround: We can get 'Weekly Attendance' or 'Timetable' and extract subjects.
      // Let's use `weekly attendance` or `timetable`.
      // Or just hardcode subject extraction from `getStudentTimetable` for now.
      
      final timetable = await _apiService.getStudentTimetable();
      final Set<String> codes = {};
      final List<Map<String, String>> uniqueSubjects = [];
      
      for (var t in timetable) {
          final code = t['subject_code'];
          final name = t['subject_name'] ?? code;
          if (!codes.contains(code)) {
              codes.add(code);
              uniqueSubjects.add({'code': code, 'name': name});
          }
      }
      
      setState(() {
        _subjects = uniqueSubjects;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() => _isLoading = false);
      // Fallback or show error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading subjects: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Books'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subjects.isEmpty
              ? const Center(child: Text("No subjects found"))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _subjects.length,
                  itemBuilder: (context, index) {
                    final subject = _subjects[index];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SubjectMaterialsScreen(subject: subject),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                subject['code'].substring(0, 2).toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject['name'],
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    subject['code'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textMuted),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
