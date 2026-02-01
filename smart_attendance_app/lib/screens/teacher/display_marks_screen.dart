import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class DisplayMarksScreen extends StatefulWidget {
  const DisplayMarksScreen({super.key});

  @override
  State<DisplayMarksScreen> createState() => _DisplayMarksScreenState();
}

class _DisplayMarksScreenState extends State<DisplayMarksScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  Map<String, dynamic>? _selectedClass;
  List<Map<String, dynamic>> _classes = [];
  Map<String, dynamic>? _sheetData;
  List<dynamic> _students = [];

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

  Future<void> _fetchSheet() async {
    if (_selectedClass == null) return;
    
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getMarksEntrySheet(
        _selectedClass!['class_id'],  
        _selectedClass!['subject_code']
      );
      setState(() {
        _sheetData = data;
        _students = data['students'];
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
      appBar: AppBar(title: const Text("Display Marks")),
      body: Column(
        children: [
          // Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.bgCard,
            child: Row(
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
                      _fetchSheet();
                    },
                  ),
                ),
              ],
            ),
          ),
          
          if (_isLoading) const Expanded(child: Center(child: CircularProgressIndicator())),
          
          if (!_isLoading && _students.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Reg No')),
                      DataColumn(label: Text('Internal\n(40)')),
                      DataColumn(label: Text('External\n(60)')),
                      DataColumn(label: Text('Total\n(100)')),
                      DataColumn(label: Text('Grade')),
                    ],
                    rows: _students.map((student) {
                      return DataRow(cells: [
                        DataCell(Text(student['name'])),
                        DataCell(Text(student['reg_no'])),
                        DataCell(Text('${student['total_internal'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text('${student['total_external'] ?? '-'}')),
                        DataCell(Text('${student['grand_total'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getGradeColor(student['grade']),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(student['grade'] ?? '-', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Color _getGradeColor(String? grade) {
    if (grade == null) return Colors.grey;
    if (grade.startsWith('O') || grade.startsWith('A')) return Colors.green;
    if (grade.startsWith('B')) return Colors.blue;
    if (grade.startsWith('C')) return Colors.orange;
    return Colors.red;
  }
}
