import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await _apiService.fetchMyProfile();
      setState(() {
        _profileData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
      appBar: AppBar(title: const Text("My Profile")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text("Error: $_error"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
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
                  ),
                ),
    );
  }
}
