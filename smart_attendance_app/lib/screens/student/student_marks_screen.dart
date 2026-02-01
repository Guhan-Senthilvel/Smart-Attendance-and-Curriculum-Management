import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentMarksScreen extends StatefulWidget {
  final List<dynamic> subjects;
  const StudentMarksScreen({super.key, required this.subjects});

  @override
  State<StudentMarksScreen> createState() => _StudentMarksScreenState();
}

class _StudentMarksScreenState extends State<StudentMarksScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  String? _selectedSubject;
  Map<String, dynamic>? _marksData;

  Future<void> _fetchMarks() async {
    if (_selectedSubject == null) return;
    
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getMyMarks(_selectedSubject!);
      setState(() {
        _marksData = data;
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
      appBar: AppBar(title: const Text("My Marks")),
      body: Container(
        color: AppTheme.bgDark,
        child: Column(
          children: [
            // Selector
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                 color: AppTheme.bgCard,
                 borderRadius: BorderRadius.circular(15),
                 border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Subject', 
                        border: OutlineInputBorder(),
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
                      ),
                      dropdownColor: AppTheme.bgCard,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      value: _selectedSubject,
                      items: widget.subjects.map<DropdownMenuItem<String>>((s) {
                        return DropdownMenuItem(
                          value: s['subject_code'],
                          child: Text("${s['subject_name']} (${s['subject_code']})", style: const TextStyle(color: AppTheme.textPrimary)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedSubject = val);
                        _fetchMarks();
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            if (_isLoading) const Expanded(child: Center(child: CircularProgressIndicator())),
            
            if (!_isLoading && _marksData != null)
               Expanded(
                 child: SingleChildScrollView(
                   padding: const EdgeInsets.all(20),
                   child: _buildMarksCard(),
                 ),
               ),
               
            if (!_isLoading && _marksData == null && _selectedSubject != null)
               const Expanded(child: Center(child: Text("No marks uploaded yet.", style: TextStyle(color: AppTheme.textSecondary, fontSize: 18)))),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMarksCard() {
    final config = _marksData!['config'] ?? {};
    final marks = _marksData!['marks'];
    final rank = _marksData!['rank'];
    final hasLab = config['has_lab'] == true;
    final isPractical = config['is_pure_practical'] == true;
    
    if (marks == null) return const Center(child: Text("Marks not entered by teacher yet.", style: TextStyle(color: AppTheme.textSecondary)));
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text(_selectedSubject!, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
          Divider(thickness: 1, height: 32, color: Colors.grey[800]),
          
          if (!isPractical) ...[
            _row("CIA Exam 1 (100)", marks['cia1_score']),
            _row("Assignment 1 (10)", marks['assign1_score']),
            const SizedBox(height: 16),
            _row("CIA Exam 2 (100)", marks['cia2_score']),
            _row("Assignment 2 (10)", marks['assign2_score']),
            const SizedBox(height: 16),
          ],

          if (isPractical) ...[
             _row("Lab Internal (50)", marks['lab_internal_score']),
             _row("Lab External (50)", marks['lab_external_score']),
             const SizedBox(height: 16),
          ] else if (hasLab) ...[
             _row("Lab Exam (50)", marks['lab_internal_score']),
             const SizedBox(height: 16),
          ],

          if (!isPractical)
             _row("Final Exam (100)", marks['final_exam_score']),
          
          Divider(thickness: 1, height: 32, color: Colors.grey[800]),
          const Center(child: Text("Converted Marks", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
          const SizedBox(height: 16),
          _row("Internal Total (${config['internal_weight'] ?? 40})", marks['total_internal'], isBold: true),
          _row("External (${config['external_weight'] ?? 60})", marks['total_external'], isBold: true),
          
          Divider(thickness: 1, height: 32, color: Colors.grey[800]),
          _row("Total Mark (100)", marks['grand_total'], isBold: true, color: AppTheme.successColor),
          _row("Grade", marks['grade'], isBold: true, isText: true),
          _row("Class Rank", rank, isBold: true),
        ],
      ),
    );
  }
  
  Widget _row(String label, dynamic value, {bool isBold = false, Color? color, bool isText = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal, 
            fontSize: 15, 
            color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary
          )),
          Text(
            value != null ? "$value" : "-", 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 16, 
              color: color ?? AppTheme.textPrimary
            )
          ),
        ],
      ),
    );
  }
}
