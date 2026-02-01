import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class SubjectMaterialsScreen extends StatefulWidget {
  final Map<String, dynamic> subject; // {code: "CS101", name: "DBMS"}

  const SubjectMaterialsScreen({super.key, required this.subject});

  @override
  State<SubjectMaterialsScreen> createState() => _SubjectMaterialsScreenState();
}

class _SubjectMaterialsScreenState extends State<SubjectMaterialsScreen> {
  final _apiService = ApiService();
  List<dynamic> _materials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    try {
      final materials = await _apiService.getSubjectEBooks(widget.subject['code']);
      setState(() {
        _materials = materials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load materials: $e')));
    }
  }

  Future<void> _downloadMaterial(int id) async {
    // For now, launch the API URL which will trigger browser download or view
    final url = _apiService.getEBookDownloadUrl(id);
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch download URL')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.subject['name']} Materials'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _materials.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_off, size: 64, color: AppTheme.textMuted),
                      const SizedBox(height: 16),
                      Text('No materials uploaded yet', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _materials.length,
                  itemBuilder: (context, index) {
                    final m = _materials[index];
                    final isPdf = m['file_type'] == 'pdf';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      shadowColor: Colors.black12,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: (isPdf ? Colors.red : Colors.blue).withOpacity(0.1),
                          child: Icon(
                            isPdf ? Icons.picture_as_pdf : Icons.image,
                            color: isPdf ? Colors.red : Colors.blue,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          m['title'],
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        subtitle: Text(
                          'Posted by ${m['teacher_name'] ?? 'Teacher'} • ${m['uploaded_at']}',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.download_rounded, color: AppTheme.primaryColor),
                          onPressed: () => _downloadMaterial(m['material_id']),
                        ),
                        onTap: () => _downloadMaterial(m['material_id']),
                      ),
                    );
                  },
                ),
    );
  }
}
