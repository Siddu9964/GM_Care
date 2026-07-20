import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'report_detail_screen.dart';

class HealthReportsScreen extends StatefulWidget {
  final String userName;
  final String location;
  final String cookie;

  const HealthReportsScreen({
    super.key,
    required this.userName,
    required this.location,
    required this.cookie,
  });

  @override
  State<HealthReportsScreen> createState() => _HealthReportsScreenState();
}

class _HealthReportsScreenState extends State<HealthReportsScreen> {
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

  void _openReportDetail(Map<String, dynamic> report) {
    HapticFeedback.lightImpact();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFE6), // Canvas background
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Premium Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: const Icon(Icons.arrow_back, color: Color(0xFF1F6B4A), size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Health Reports",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A), letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "YOUR MEDICAL DOSSIER",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF1F6B4A).withOpacity(0.5), letterSpacing: 1.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            // 2. Reports List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1F6B4A)))
                  : _errorMsg.isNotEmpty
                      ? Center(child: Text(_errorMsg, style: const TextStyle(color: Colors.red)))
                      : _reports.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                              physics: const BouncingScrollPhysics(),
                              itemCount: _reports.length,
                              itemBuilder: (context, index) {
                                return _AnimatedReportCard(
                                  index: index,
                                  report: _reports[index],
                                  onTap: () => _openReportDetail(_reports[index]),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFF1F6B4A).withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Icon(Icons.folder_shared_rounded, size: 64, color: const Color(0xFF1F6B4A).withOpacity(0.3)),
          ),
          const SizedBox(height: 24),
          const Text(
            "No health reports found",
            style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A), fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            "Your consultation records will appear here.",
            style: TextStyle(fontWeight: FontWeight.w600, color: const Color(0xFF1F6B4A).withOpacity(0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _AnimatedReportCard extends StatefulWidget {
  final int index;
  final dynamic report;
  final VoidCallback onTap;

  const _AnimatedReportCard({
    required this.index,
    required this.report,
    required this.onTap,
  });

  @override
  State<_AnimatedReportCard> createState() => _AnimatedReportCardState();
}

class _AnimatedReportCardState extends State<_AnimatedReportCard> with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnimation = Tween<double>(begin: 60, end: 0).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
    
    Future.delayed(Duration(milliseconds: 100 + (widget.index * 100)), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(widget.report['consultation_date']);
    
    // Extract actual doctor name (using the backend join fix we implemented earlier)
    String doctorName = widget.report['doctor_name'] ?? widget.report['doctor_id'] ?? 'Unknown Doctor';
    if (!doctorName.toLowerCase().startsWith('dr.') && !doctorName.startsWith('DOC')) {
      doctorName = 'Dr. $doctorName';
    }
    
    // Try to get a meaningful title
    String title = "Clinical Report";
    if (widget.report['diagnosis'] != null && widget.report['diagnosis'].toString().isNotEmpty) {
      title = widget.report['diagnosis'].toString();
    } else if (widget.report['final_diagnosis'] != null && widget.report['final_diagnosis'].toString().isNotEmpty) {
      title = widget.report['final_diagnosis'].toString();
    } else if (widget.report['department'] != null && widget.report['department'].toString().isNotEmpty) {
      title = "${widget.report['department']} Consultation";
    }

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1F6B4A).withOpacity(0.04), 
                blurRadius: 24, 
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Status Badge and Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4F1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "READY",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF1F6B4A).withOpacity(0.4)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Middle Row: Title & Doctor Name
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A), letterSpacing: -0.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 14, color: const Color(0xFF1F6B4A).withOpacity(0.5)),
                  const SizedBox(width: 6),
                  Text(
                    doctorName,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1F6B4A).withOpacity(0.6)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Bottom Row: Consultation ID and Action Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Consultation ID",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF1F6B4A).withOpacity(0.5), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.report['consultation_id'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1F6B4A)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EFE6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text("View Report", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1F6B4A))),
                        SizedBox(width: 6),
                        Icon(Icons.description_outlined, size: 14, color: Color(0xFF1F6B4A)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
