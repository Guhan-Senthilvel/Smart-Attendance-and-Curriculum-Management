import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class TeacherInboxScreen extends StatefulWidget {
  const TeacherInboxScreen({super.key});

  @override
  State<TeacherInboxScreen> createState() => _TeacherInboxScreenState();
}

class _TeacherInboxScreenState extends State<TeacherInboxScreen> {
  final _apiService = ApiService();
  List<dynamic> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final data = await _apiService.getTeacherInbox();
      setState(() {
        _requests = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _approveRequests(List<int> approvalIds) async {
    try {
      await _apiService.approveRequestGroup(approvalIds);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approved ${approvalIds.length} requests ✅'), backgroundColor: Colors.green),
      );
      _loadData(); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectRequests(List<int> approvalIds) async {
    try {
      await _apiService.rejectRequestGroup(approvalIds);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rejected ${approvalIds.length} requests ❌'), backgroundColor: Colors.red),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _viewProof(int requestId) async {
    final url = _apiService.getRequestProofUrl(requestId);
    if (!await launchUrl(Uri.parse(url))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open proof')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _requests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: AppTheme.textMuted),
                          const SizedBox(height: 16),
                          Text('No pending requests', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        return _buildRequestCard(_requests[index]);
                      },
                    ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final type = req['request_type'] as String;
    final isOD = type == 'OD';
    final requestId = req['request_id'] as int;
    
    // Parse approval IDs safely
    final approvalIds = (req['approval_ids'] as List<dynamic>).map((e) => e as int).toList();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isOD ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOD ? 'ON DUTY REQUEST' : 'MEDICAL LEAVE',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: isOD ? Colors.blue : Colors.orange,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    req['date_sent'] ?? '',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Student', '${req['student_name']}'),
                _buildInfoRow('Register No', '${req['student_reg_no']}'),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                // Show session info which contains periods
                _buildInfoRow('Details', '${req['session_info']}'),
                
                const SizedBox(height: 16),
                
                // Proof Button
                if (req['proof_available'] == true)
                  OutlinedButton.icon(
                    onPressed: () => _viewProof(requestId),
                    icon: const Icon(Icons.description, size: 18),
                    label: const Text('View Proof Attachment'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                    ),
                  ),
              ],
            ),
          ),
          
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveRequests(approvalIds),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOD ? Colors.blue : Colors.orange, 
                    ),
                    child: Text('Approve All (${approvalIds.length})'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectRequests(approvalIds),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                    ),
                    child: Text('Reject All (${approvalIds.length})'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
