import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class MarksStatisticsScreen extends StatefulWidget {
  const MarksStatisticsScreen({super.key});

  @override
  State<MarksStatisticsScreen> createState() => _MarksStatisticsScreenState();
}

class _MarksStatisticsScreenState extends State<MarksStatisticsScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  Map<String, dynamic>? _selectedClass;
  List<Map<String, dynamic>> _classes = [];
  Map<String, dynamic>? _stats;
  String _selectedExamType = "Final Result";

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await _apiService.getTeacherClasses();
      setState(() {
        _classes = List<Map<String, dynamic>>.from(classes);
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _fetchStats() async {
    if (_selectedClass == null) return;
    
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getMarksStatistics(
        _selectedClass!['class_id'],  
        _selectedClass!['subject_code'],
        _selectedExamType
      );
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Marks Statistics")),
      body: Column(
        children: [
          // Selector
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Map<String, dynamic>>(
                        decoration: const InputDecoration(labelText: 'Select Class & Subject', border: OutlineInputBorder()),
                        value: _selectedClass,
                        isExpanded: true,
                        items: _classes.map((c) {
                          final className = "${c['dept_name'] ?? ''} ${c['year'] ?? ''}-${c['section'] ?? ''}";
                          return DropdownMenuItem(
                            value: c,
                            child: Text("$className - ${c['subject_name']} (${c['subject_code']})", overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedClass = val);
                          _fetchStats();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_selectedClass != null)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Exam Type', border: OutlineInputBorder()),
                    value: _selectedExamType,
                    items: ["CIA 1", "CIA 2", "Final Exam", "Final Result"].map((e) {
                      return DropdownMenuItem(value: e, child: Text(e));
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedExamType = val!);
                      _fetchStats();
                    },
                  ),
              ],
            ),
          ),
          
          if (_isLoading) const Expanded(child: Center(child: CircularProgressIndicator())),
          
          if (!_isLoading && _stats != null)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     // Overview Cards
                     Row(
                       children: [
                         _buildStatCard("Total", "${_stats!['total_students']}", Colors.blue),
                         const SizedBox(width: 10),
                         _buildStatCard("Pass", "${_stats!['passed']}", Colors.green),
                         const SizedBox(width: 10),
                         _buildStatCard("Fail", "${_stats!['failed']}", Colors.red),
                       ],
                     ),
                     const SizedBox(height: 16),
                     Row(
                       children: [
                         _buildStatCard("Top", "${_stats!['top_mark']}", Colors.purple),
                         const SizedBox(width: 10),
                         _buildStatCard("Avg", "${_stats!['avg_mark']}", Colors.orange),
                         const SizedBox(width: 10),
                         _buildStatCard("Low", "${_stats!['low_mark']}", Colors.brown),
                       ],
                     ),
                     const SizedBox(height: 24),
                     
                     const Text("Grade Distribution", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 12),
                     ...(_stats!['grade_dist'] as Map<String, dynamic>).entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(width: 30, child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: e.value / (_stats!['total_students'] ?? 1),
                                  backgroundColor: Colors.grey[200],
                                  color: AppTheme.primaryColor,
                                  minHeight: 10,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text("${e.value}"),
                            ],
                          ),
                        );
                     }),
                     
                     const SizedBox(height: 24),
                     const Text("Top Performers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                     ...(_stats!['top_performers'] as List).map((s) => ListTile(
                       title: Text(s['name']),
                       trailing: Text("${s['mark']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                       dense: true,
                     )),
                     
                     const SizedBox(height: 16),
                     const Text("Needs Improvement", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                     ...(_stats!['needs_improvement'] as List).map((s) => ListTile(
                       title: Text(s['name']),
                       trailing: Text("${s['mark']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                       dense: true,
                     )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}
