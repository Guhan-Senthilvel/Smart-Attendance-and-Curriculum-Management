import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import 'upload_work_screen.dart';

class SubjectTasksScreen extends StatefulWidget {
  final String subjectCode;
  final String? subjectName;

  const SubjectTasksScreen({super.key, required this.subjectCode, this.subjectName});

  @override
  State<SubjectTasksScreen> createState() => _SubjectTasksScreenState();
}

class _SubjectTasksScreenState extends State<SubjectTasksScreen> {
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
      final tasks = await _apiService.getStudentTasks(subjectCode: widget.subjectCode);
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
  String _selectedType = 'Daily'; // Default to Daily

  @override
  Widget build(BuildContext context) {
    // Filter tasks based on selection
    final filteredTasks = _tasks.where((t) => t['type'] == _selectedType).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.subjectName ?? 'Activities (${widget.subjectCode})')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Filter Section
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppTheme.bgCard,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Select Category:", style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: _selectedType,
                        underline: Container(height: 2, color: AppTheme.primaryColor),
                        items: const [
                          DropdownMenuItem(value: 'Daily', child: Text('Daily Work')),
                          DropdownMenuItem(value: 'Assignment', child: Text('Assignment')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedType = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                
                // Task List Section
                Expanded(
                  child: filteredTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 48, color: AppTheme.textMuted),
                              const SizedBox(height: 12),
                              Text("No ${_selectedType.toLowerCase()} found.", style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            final isSubmitted = task['is_submitted'] == true;
                            
                            return GestureDetector(
                              onTap: () {
                                 Navigator.push(
                                   context,
                                   MaterialPageRoute(builder: (_) => UploadWorkScreen(taskId: task['task_id'], isSubmitted: isSubmitted)),
                                 ).then((_) => _loadTasks());
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                     Row(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                         Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                           decoration: BoxDecoration(
                                             color: AppTheme.primaryColor.withOpacity(0.1),
                                             borderRadius: BorderRadius.circular(4),
                                           ),
                                           child: Text(
                                             task['type'],
                                             style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                                           ),
                                         ),
                                         Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                           decoration: BoxDecoration(
                                             color: isSubmitted ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                                             borderRadius: BorderRadius.circular(4),
                                           ),
                                           child: Text(
                                             isSubmitted ? 'Submitted' : 'Not Submitted',
                                             style: TextStyle(
                                               color: isSubmitted ? Colors.green : Colors.orange,
                                               fontSize: 10,
                                               fontWeight: FontWeight.bold
                                             ),
                                           ),
                                         ),
                                       ],
                                     ),
                                     const SizedBox(height: 8),
                                     Text(
                                       task['title'],
                                       style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                     ),
                                     const SizedBox(height: 8),
                                     Text(
                                       'Due: ${task['deadline'] != null ? task['deadline'].toString().split('T')[0] : 'None'}',
                                       style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                     ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
