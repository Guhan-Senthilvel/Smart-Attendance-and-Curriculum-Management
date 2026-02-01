import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import 'subject_tasks_screen.dart';

class StudentTasksHome extends StatefulWidget {
  const StudentTasksHome({super.key});

  @override
  State<StudentTasksHome> createState() => _StudentTasksHomeState();
}

class _StudentTasksHomeState extends State<StudentTasksHome> {
  final _apiService = ApiService();
  bool _isLoading = true;
  List<Map<String, String>> _subjects = [];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final timetable = await _apiService.getStudentTimetable();
      final Map<String, String> uniqueSubjects = {};
      
      for (var entry in timetable) {
        if (entry['subject_code'] != null) {
          final code = entry['subject_code'] as String;
          final name = entry['subject_name'] ?? code;
          uniqueSubjects[code] = name;
        }
      }
      
      setState(() {
        _subjects = uniqueSubjects.entries.map((e) => {'code': e.key, 'name': e.value}).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading subjects: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Activities')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subjects.isEmpty
              ? Center(child: Text('No subjects found.', style: GoogleFonts.inter(color: AppTheme.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _subjects.length,
                  itemBuilder: (context, index) {
                    final subject = _subjects[index];
                    final code = subject['code']!;
                    final name = subject['name']!;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 0,
                      color: AppTheme.bgCard,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppTheme.borderColor)
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(20),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.book, color: Colors.blue),
                        ),
                        title: Text(
                          name,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        subtitle: Text(
                          code,
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.textMuted, size: 16),
                        onTap: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(builder: (_) => SubjectTasksScreen(subjectCode: code, subjectName: name)),
                           );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
