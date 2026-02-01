import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key});

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  
  // Selection
  Map<String, dynamic>? _selectedClass;
  List<Map<String, dynamic>> _classes = [];
  
  // Data
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

  Future<void> _saveMarks() async {
    if (_selectedClass == null) return;
    
    setState(() => _isLoading = true);
    try {
      final updates = _students.map((s) => {
        'student_id': s['student_id'],
        'reg_no': s['reg_no'],
        'name': s['name'],
        'cia1_score': s['cia1_score'],
        'cia2_score': s['cia2_score'],
        'assign1_score': s['assign1_score'],
        'assign2_score': s['assign2_score'],
        'final_exam_score': s['final_exam_score'],
        'lab_internal_score': s['lab_internal_score'],
        'lab_external_score': s['lab_external_score'],
      }).toList();
      
      await _apiService.saveMarks(
        _selectedClass!['class_id'],  
        _selectedClass!['subject_code'], 
        updates
      );
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marks saved successfully!')));
      _fetchSheet(); // Refresh to see calculated totals
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Marks Entry")),
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
                scrollDirection: Axis.vertical,
                padding: const EdgeInsets.only(bottom: 80), // Space for FAB
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.grey[300]),
                    child: DataTable(
                      columnSpacing: 16,
                      horizontalMargin: 12,
                      headingRowColor: MaterialStateProperty.all(AppTheme.bgCardLight),
                      border: TableBorder.all(color: Colors.grey[300]!, width: 1),
                      columns: _buildColumns(),
                      rows: _students.map((student) {
                        return DataRow(cells: _buildCells(student));
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _students.isNotEmpty 
          ? FloatingActionButton.extended(
              onPressed: _saveMarks, 
              label: const Text("Save Marks"), 
              icon: const Icon(Icons.save),
              backgroundColor: AppTheme.primaryColor,
            ) 
          : null,
    );
  }

  List<DataColumn> _buildColumns() {
    final config = _sheetData!['config'] ?? {};
    final hasLab = config['has_lab'] == true;
    final isPractical = config['is_pure_practical'] == true;
    final intWeight = config['internal_weight'] ?? 40;
    
    List<DataColumn> cols = [
      const DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
      const DataColumn(label: Text('Reg No', style: TextStyle(fontWeight: FontWeight.bold))),
    ];

    if (!isPractical) {
      cols.addAll([
        const DataColumn(label: SizedBox(width: 60, child: Text('CIA-1\n(100)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))),
        const DataColumn(label: SizedBox(width: 60, child: Text('Asgn-1\n(10)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))),
        const DataColumn(label: SizedBox(width: 60, child: Text('CIA-2\n(100)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))),
        const DataColumn(label: SizedBox(width: 60, child: Text('Asgn-2\n(10)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))),
      ]);
    }

    if (isPractical) {
       cols.add(const DataColumn(label: SizedBox(width: 60, child: Text('Lab Int\n(50)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))));
       cols.add(const DataColumn(label: SizedBox(width: 60, child: Text('Lab Ext\n(50)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))));
    } else if (hasLab) {
       // Theory + Lab: Show only one Lab column (Internal 50 -> 10)
       cols.add(const DataColumn(label: SizedBox(width: 60, child: Text('Lab\n(50)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))));
    }

    if (!isPractical) {
      cols.add(const DataColumn(label: SizedBox(width: 60, child: Text('Final\n(100)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))));
    }

    cols.add(DataColumn(label: Text('Internal\n($intWeight)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))));
    cols.add(const DataColumn(label: Text('Grade\nResult', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))));

    return cols;
  }

  List<DataCell> _buildCells(Map<String, dynamic> student) {
    final config = _sheetData!['config'] ?? {};
    final hasLab = config['has_lab'] == true;
    final isPractical = config['is_pure_practical'] == true;

    List<DataCell> cells = [
      DataCell(SizedBox(width: 100, child: Text(student['name'], overflow: TextOverflow.ellipsis))),
      DataCell(Text(student['reg_no'])),
    ];

    if (!isPractical) {
       cells.addAll([
         _editableCell(student, 'cia1_score'),
         _editableCell(student, 'assign1_score'),
         _editableCell(student, 'cia2_score'),
         _editableCell(student, 'assign2_score'),
       ]);
    }

    if (isPractical) {
       cells.add(_editableCell(student, 'lab_internal_score'));
       cells.add(_editableCell(student, 'lab_external_score'));
    } else if (hasLab) {
       cells.add(_editableCell(student, 'lab_internal_score'));
    }

    if (!isPractical) {
      cells.add(_editableCell(student, 'final_exam_score'));
    }

    cells.add(DataCell(Center(child: Text('${student['total_internal'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)))));
    cells.add(DataCell(Center(child: Text('${student['grade'] ?? '-'}', style: TextStyle(fontWeight: FontWeight.bold, color: student['status'] == 'Fail' ? Colors.red : Colors.green)))));

    return cells;
  }

  DataCell _editableCell(Map<String, dynamic> student, String key) {
    return DataCell(
      Container(
        width: 70,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextFormField(
          initialValue: student[key]?.toString() ?? '',
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4), 
              borderSide: const BorderSide(color: Colors.white24)
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4), 
              borderSide: const BorderSide(color: Colors.white24)
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4), 
              borderSide: const BorderSide(color: AppTheme.primaryColor)
            ),
            filled: true,
            fillColor: AppTheme.bgCardLight.withOpacity(0.5),
          ),
          onChanged: (val) {
             if (val.isEmpty) {
               student[key] = null;
             } else {
               student[key] = double.tryParse(val);
             }
          },
        ),
      ),
    );
  }
}
