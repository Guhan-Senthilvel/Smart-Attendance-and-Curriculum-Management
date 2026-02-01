import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class RaiseRequestScreen extends StatefulWidget {
  const RaiseRequestScreen({super.key});

  @override
  State<RaiseRequestScreen> createState() => _RaiseRequestScreenState();
}

class _RaiseRequestScreenState extends State<RaiseRequestScreen> {
  final _apiService = ApiService();
  String _selectedType = 'OD'; // OD or ML
  DateTimeRange? _selectedDateRange;
  Set<int> _selectedPeriods = {};
  bool _isAllPeriods = false;
  File? _selectedFile;
  bool _isSubmitting = false;

  void _togglePeriod(int period) {
    setState(() {
      if (_selectedPeriods.contains(period)) {
        _selectedPeriods.remove(period);
        _isAllPeriods = false;
      } else {
        _selectedPeriods.add(period);
        if (_selectedPeriods.length == 7) _isAllPeriods = true;
      }
    });
  }

  void _toggleAllPeriods(bool? value) {
    setState(() {
      _isAllPeriods = value ?? false;
      if (_isAllPeriods) {
        _selectedPeriods = {1, 2, 3, 4, 5, 6, 7};
      } else {
        _selectedPeriods.clear();
      }
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submitRequest() async {
    if (_selectedDateRange == null ||
        _selectedPeriods.isEmpty ||
        _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and upload proof')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final periodsStr = _selectedPeriods.join(',');
      final fromDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start);
      final toDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end);

      await _apiService.submitLeaveRequest(
        type: _selectedType,
        fromDate: fromDate,
        toDate: toDate,
        periods: periodsStr,
        proofFile: _selectedFile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Request submitted successfully!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to submit: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raise OD/ML Request')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Raise Request',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // Type Dropdown
            Text('Type',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.bgCardLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'OD', child: Text('On Duty (OD)')),
                    DropdownMenuItem(
                        value: 'ML', child: Text('Medical Leave (ML)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedType = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date Duration
            Text('Date Duration',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now(),
                );
                if (range != null) setState(() => _selectedDateRange = range);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCardLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDateRange == null
                          ? 'Select Dates'
                          : '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}',
                      style: TextStyle(
                        color: _selectedDateRange == null
                            ? AppTheme.textMuted
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Periods
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Periods',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                Row(
                  children: [
                    Checkbox(
                      value: _isAllPeriods,
                      onChanged: _toggleAllPeriods,
                    ),
                    const Text('All'),
                  ],
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (index) {
                final p = index + 1;
                final isSelected = _selectedPeriods.contains(p);
                return FilterChip(
                  label: Text(p.toString()),
                  selected: isSelected,
                  onSelected: (bool selected) => _togglePeriod(p),
                  selectedColor: AppTheme.primaryColor.withOpacity(0.2),
                  checkmarkColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Upload Proof
            Text('Upload Proof',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.textMuted.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.bgCard,
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload_outlined,
                        size: 32, color: AppTheme.primaryColor),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFile != null
                          ? _selectedFile!.path.split('/').last
                          : 'Choose File (Image/PDF)',
                      style: TextStyle(
                          color: _selectedFile != null
                              ? AppTheme.textPrimary
                              : AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
