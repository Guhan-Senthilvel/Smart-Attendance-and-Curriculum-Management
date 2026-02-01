import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class StudentProfileLookupScreen extends StatefulWidget {
  const StudentProfileLookupScreen({super.key});

  @override
  State<StudentProfileLookupScreen> createState() => _StudentProfileLookupScreenState();
}

class _StudentProfileLookupScreenState extends State<StudentProfileLookupScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  
  List<dynamic> _classes = [];
  Map<String, dynamic>? _selectedClass;
  
  List<dynamic> _students = [];
  Map<String, dynamic>? _selectedStudent;
  
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoading = true);
    try {
      final List<dynamic> rawData = await _apiService.getTeacherClasses();
      
      // Deduplicate classes based on class_id
      final uniqueClasses = <String, Map<String, dynamic>>{};
      for (var item in rawData) {
        if (!uniqueClasses.containsKey(item['class_id'])) {
          uniqueClasses[item['class_id']] = item;
        }
      }
      
      setState(() => _classes = uniqueClasses.values.toList());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading classes: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStudents() async {
    if (_selectedClass == null) return;
    setState(() {
      _isLoading = true;
      _students = [];
      _selectedStudent = null;
      _profileData = null;
    });
    
    try {
      final data = await _apiService.fetchStudentsByClass(_selectedClass!['class_id']);
      setState(() => _students = data);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading students: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProfile() async {
    if (_selectedStudent == null) return;
    setState(() {
      _isLoading = true;
      _profileData = null;
    });
    
    try {
      final data = await _apiService.fetchStudentProfile(_selectedStudent!['student_id']);
      setState(() => _profileData = data);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140, 
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))
          ),
          Expanded(
            child: Text(value ?? '-', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Select Class
            DropdownButtonFormField<Map<String, dynamic>>(
              decoration: const InputDecoration(labelText: 'Select Class', border: OutlineInputBorder()),
              value: _selectedClass,
              items: _classes.map<DropdownMenuItem<Map<String, dynamic>>>((c) { // Fixed type
                return DropdownMenuItem(
                  value: c,
                  child: Text("${c['dept_name']} ${c['year']} - ${c['section']}"), 
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedClass = val);
                _fetchStudents();
              },
            ),
            const SizedBox(height: 20),
            
            // Select Student
            DropdownButtonFormField<Map<String, dynamic>>(
              decoration: const InputDecoration(labelText: 'Select Student', border: OutlineInputBorder()),
              value: _selectedStudent,
              items: _students.map<DropdownMenuItem<Map<String, dynamic>>>((s) { // Fixed type
                return DropdownMenuItem(
                  value: s,
                  child: Text("${s['reg_no']} - ${s['name']}"),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedStudent = val);
                _fetchProfile();
              },
              disabledHint: const Text("Select Class First"),
            ),
            const SizedBox(height: 30),

            if (_isLoading) const CircularProgressIndicator(),

            if (_profileData != null) ...[
               Container(
                 padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(
                   color: AppTheme.bgCard,
                   borderRadius: BorderRadius.circular(15),
                   boxShadow: AppTheme.cardShadow,
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Center(
                       child: Column(
                         children: [
                           CircleAvatar(
                             radius: 40,
                             backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                             child: const Icon(Icons.person, size: 40, color: AppTheme.primaryColor),
                           ),
                           const SizedBox(height: 10),
                           Text(_profileData!['name'] ?? '', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold)),
                           Text(_profileData!['reg_no'] ?? '', style: const TextStyle(color: Colors.grey)),
                         ],
                       ),
                     ),
                     const Divider(height: 40),
                     Text("Personal Details", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                     const SizedBox(height: 10),
                     _buildDetailRow("Class", _profileData!['class_name']),
                     _buildDetailRow("Department", _profileData!['dept_name']),
                     _buildDetailRow("Personal Email", _profileData!['personal_email']),
                     _buildDetailRow("Student Mobile", _profileData!['student_mobile']),
                     
                     const Divider(height: 30),
                     Text("Family & Address", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                     const SizedBox(height: 10),
                     _buildDetailRow("Father's Mobile", _profileData!['father_mobile']),
                     _buildDetailRow("Mother's Mobile", _profileData!['mother_mobile']),
                     _buildDetailRow("Address", _profileData!['address']),
                     _buildDetailRow("State", _profileData!['state']),

                     const Divider(height: 30),
                     Text("Academic History", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                     const SizedBox(height: 10),
                     _buildDetailRow("10th Mark", _profileData!['tenth_mark']),
                     _buildDetailRow("12th Mark", _profileData!['twelfth_mark']),
                   ],
                 ),
               ),
            ],
          ],
        ),
      ),
    );
  }
}
