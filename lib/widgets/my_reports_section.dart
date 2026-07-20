import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../screens/report_detail_screen.dart';

class MyReportsSection extends StatefulWidget {
  final String userName;
  final String location;
  final String cookie;

  const MyReportsSection({
    super.key,
    required this.userName,
    required this.location,
    required this.cookie,
  });

  @override
  State<MyReportsSection> createState() => _MyReportsSectionState();
}

class _MyReportsSectionState extends State<MyReportsSection> {
  bool _isLoading = true;
  String _errorMsg = '';
  List<dynamic> _reports = [];

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      final searchRes = await http.get(
        Uri.parse(ApiConfig.patientSearch(widget.userName)),
        headers: {
          'X-Hospital-Branch': widget.location,
          'Accept': 'application/json',
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
      );

      if (searchRes.statusCode != 200) throw Exception("Failed to find patient details.");
      final searchJson = jsonDecode(searchRes.body);
      final patientsList = searchJson['data']?['data'] ?? [];
      
      if (patientsList.isEmpty) {
        if (mounted) setState(() { _isLoading = false; });
        return;
      }
      
      final patientId = patientsList[0]['patient_id'] ?? '';
      if (patientId.isEmpty) throw Exception("Invalid Patient ID.");

      final reportsRes = await http.get(
        Uri.parse('${ApiConfig.consultations}?patient_id=$patientId'),
        headers: {
          'X-Hospital-Branch': widget.location,
          'Accept': 'application/json',
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
      );

      if (reportsRes.statusCode == 200) {
        final reportsJson = jsonDecode(reportsRes.body);
        final List<dynamic> allConsults = reportsJson['data'] ?? [];
        if (mounted) {
          setState(() {
            _reports = allConsults;
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to load reports.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = e.toString();
        });
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Unknown Date";
    try {
      DateTime dt = DateTime.parse(dateStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
    } catch (_) {
      return dateStr;
    }
  }

  void _openReportDetail(Map<String, dynamic> report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportDetailScreen(
          reportData: report,
          location: widget.location,
          cookie: widget.cookie,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_reports.isEmpty && !_isLoading && _errorMsg.isEmpty) {
      return const SizedBox.shrink(); 
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Health Reports",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
            ),
            if (_reports.isNotEmpty)
              Text(
                "View Files",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1F6B4A)),
              )
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140, 
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1F6B4A)))
              : _errorMsg.isNotEmpty
                  ? Center(child: Text(_errorMsg, style: const TextStyle(color: Colors.red)))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _reports.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final rep = _reports[index];
                        final dateStr = _formatDate(rep['consultation_date']);
                        final title = rep['department'] ?? 'Clinical Report';
                        
                        return InkWell(
                          onTap: () => _openReportDetail(rep),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 150,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F7FB),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                Positioned(
                                  top: -20,
                                  right: -20,
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0).withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6F4F1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        "READY",
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF1F6B4A)),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      title,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E293B)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                                    ),
                                    const SizedBox(height: 8),
                                    const Align(
                                      alignment: Alignment.bottomRight,
                                      child: Icon(Icons.download_outlined, color: Color(0xFF1F6B4A), size: 18),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
