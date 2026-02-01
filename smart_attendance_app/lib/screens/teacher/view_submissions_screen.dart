import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import 'task_submissions_screen.dart';

class ViewSubmissionsScreen extends StatefulWidget {
  const ViewSubmissionsScreen({super.key});

  @override
  State<ViewSubmissionsScreen> createState() => _ViewSubmissionsScreenState();
}

class _ViewSubmissionsScreenState extends State<ViewSubmissionsScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await _apiService.getTeacherTasks();
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Submissions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? Center(child: Text('No tasks created yet.', style: GoogleFonts.inter(color: AppTheme.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 0,
                      color: AppTheme.bgCard,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppTheme.borderColor)
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          task['title'],
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (task['type'] == 'Assignment' ? Colors.purple : Colors.blue).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    task['type'],
                                    style: TextStyle(
                                      color: task['type'] == 'Assignment' ? Colors.purpleAccent : Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Class ${task['class_id']} - ${task['subject_code']}',
                                  style: TextStyle(color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Deadline: ${task['deadline'] != null ? task['deadline'].toString().split('T')[0] : 'None'}',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: AppTheme.textMuted, size: 16),
                        onTap: () {
                           Navigator.push(
                             context,
                             MaterialPageRoute(builder: (_) => TaskSubmissionsScreen(taskId: task['task_id'], taskTitle: task['title'])),
                           );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
