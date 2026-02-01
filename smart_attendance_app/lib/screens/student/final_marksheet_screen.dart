import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class FinalMarksheetScreen extends StatefulWidget {
  const FinalMarksheetScreen({super.key});

  @override
  State<FinalMarksheetScreen> createState() => _FinalMarksheetScreenState();
}

class _FinalMarksheetScreenState extends State<FinalMarksheetScreen> {
  final _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      print("Fetching Final Marksheet...");
      final data = await _apiService.getFinalMarksheet();
      print("Final Marksheet Data: $data");
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching marksheet: $e");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Semester Result")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _data == null || _data!['results'] == null
           ? Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Icon(Icons.description_outlined, size: 60, color: Colors.grey),
                   const SizedBox(height: 16),
                   const Text("No results found.", style: TextStyle(fontSize: 16, color: Colors.grey)),
                   ElevatedButton(onPressed: _fetchData, child: const Text("Retry"))
                 ],
               ),
             )
           : _data!['all_published'] == false
               ? Center(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       const Icon(Icons.hourglass_bottom, size: 60, color: Colors.orange),
                       const SizedBox(height: 16),
                       const Text("Results Pending", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 8),
                       const Padding(
                         padding: EdgeInsets.symmetric(horizontal: 40),
                         child: Text("Marks for all subjects have not been published yet. Please check back later.", textAlign: TextAlign.center),
                       ),
                       const SizedBox(height: 16),
                       ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Go Back"))
                     ],
                   ),
                 )
               : SingleChildScrollView(
                   padding: const EdgeInsets.all(20),
                   child: Container(
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(
                   color: Colors.white,
                   border: Border.all(color: Colors.black),
                 ),
                 child: DefaultTextStyle(
                   style: GoogleFonts.inter(color: Colors.black),
                   child: Column(
                   crossAxisAlignment: CrossAxisAlignment.center,
                   children: [
                     const Text(
                       "Hindusthan College of Engineering And Technology",
                       textAlign: TextAlign.center,
                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                     ),
                     const SizedBox(height: 8),
                     const Text("Semester Examination Result", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                     const Divider(thickness: 2, color: Colors.black, height: 32),
                     
                     _detailsRow("Roll No", _data!['reg_no']),
                     _detailsRow("Name", _data!['student_name']),
                     _detailsRow("Class", _data!['class']), 
                     _detailsRow("Batch", _data!['batch']),
                     
                     const Divider(thickness: 2, color: Colors.black, height: 32),
                     
                     Table(
                       border: TableBorder.all(color: Colors.black54),
                       columnWidths: const {
                         0: FlexColumnWidth(1.2),
                         1: FlexColumnWidth(3),
                         2: FlexColumnWidth(1),
                         3: FlexColumnWidth(1.2),
                       },
                       children: [
                         const TableRow(children: [
                           Padding(padding: EdgeInsets.all(8), child: Text("Sub Code", style: TextStyle(fontWeight: FontWeight.bold))),
                           Padding(padding: EdgeInsets.all(8), child: Text("Subject Name", style: TextStyle(fontWeight: FontWeight.bold))),
                           Padding(padding: EdgeInsets.all(8), child: Text("Grade", style: TextStyle(fontWeight: FontWeight.bold))),
                           Padding(padding: EdgeInsets.all(8), child: Text("Result", style: TextStyle(fontWeight: FontWeight.bold))),
                         ]),
                         ...(_data!['results'] as List).map((r) => TableRow(children: [
                           Padding(padding: const EdgeInsets.all(8), child: Text(r['subject_code'])),
                           Padding(padding: const EdgeInsets.all(8), child: Text(r['subject_name'])),
                           Padding(padding: const EdgeInsets.all(8), child: Text(r['grade'] ?? '-')),
                           Padding(padding: const EdgeInsets.all(8), child: Text(r['status'] ?? '-')),
                         ])),
                       ],
                     ),
                     
                     const SizedBox(height: 32),
                     OutlinedButton.icon(
                       onPressed: () {
                         // Download PDF Logic (Future)
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDF Download feature coming soon!")));
                       },
                       icon: const Icon(Icons.download),
                       label: const Text("Download PDF"),
                     )
                   ],
                   ),
                 ),
               ),
             ),
    );
  }
  
  Widget _detailsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          const Text(" : "),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
