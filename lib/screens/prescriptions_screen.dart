import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

const Color _kPrimary = Color(0xFF1BA6B1);
const Color _kPrimaryDark = Color(0xFF0E4D54);
const Color _kAccent = Color(0xFF1596A1);
const Color _kBg = Color(0xFFF3EFE6);
const Color _kBorder = Color(0xFFDED8CB);
const Color _kTextMuted = Color(0xFF5A6E64);

class PrescriptionsScreen extends StatefulWidget {
  final String userName;
  final String location;
  final String cookie;
  final String patientId;
  final String age;
  final String sex;

  const PrescriptionsScreen({
    super.key,
    required this.userName,
    required this.location,
    required this.cookie,
    this.patientId = '',
    this.age = '--',
    this.sex = 'Unknown',
  });

  /// Standard URL resolver: guarantees valid absolute HTTP/HTTPS URL for PDFs
  static String resolvePdfUrl(dynamic item) {
    if (item == null) return '';
    if (item is String) return formatPdfUrl(item);
    if (item is! Map) return '';

    // 1. Direct PDF URL candidates in priority order
    final candidates = [
      item['prescription_pdf_url'],
      item['prescription_pdf'],
      item['pdf_url'],
      item['report_file'],
      item['report_url'],
      item['pdf'],
      item['file_url'],
      item['download_url'],
    ];

    for (final c in candidates) {
      if (c != null) {
        final str = c.toString().trim();
        if (str.isNotEmpty && str.toLowerCase() != 'null') {
          final formatted = formatPdfUrl(str);
          if (formatted.isNotEmpty) return formatted;
        }
      }
    }

    // 2. Check JSON string in result_data (common in radiology/scan reports)
    if (item['result_data'] != null) {
      try {
        final rd = item['result_data'];
        final Map<String, dynamic> parsed = rd is Map
            ? Map<String, dynamic>.from(rd)
            : jsonDecode(rd.toString());
        final rdCandidates = [
          parsed['report_url'],
          parsed['image_url'],
          parsed['report_file'],
        ];
        for (final rc in rdCandidates) {
          if (rc != null) {
            final str = rc.toString().trim();
            if (str.isNotEmpty && str.toLowerCase() != 'null') {
              final formatted = formatPdfUrl(str);
              if (formatted.isNotEmpty) return formatted;
            }
          }
        }
      } catch (_) {}
    }

    return '';
  }

  /// Normalizes relative or absolute PDF paths into full GM HMS URLs
  static String formatPdfUrl(String raw) {
    String clean = raw.trim();
    if (clean.isEmpty || clean.toLowerCase() == 'null') return '';

    // 1. Full absolute URL (e.g. somatiq.ai share links or external PDFs)
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }

    // 2. Starts with /GM_HMS/ or GM_HMS/
    if (clean.startsWith('/GM_HMS/')) {
      return 'https://erp.gmhospitals.co.in$clean';
    }
    if (clean.startsWith('GM_HMS/')) {
      return 'https://erp.gmhospitals.co.in/$clean';
    }

    // 3. Relative path like consultation/opd_pdf/pdf_...
    if (clean.startsWith('/')) {
      clean = clean.substring(1);
    }
    return 'https://erp.gmhospitals.co.in/GM_HMS/$clean';
  }

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  bool _isLoading = true;
  String _errorMsg = '';
  String _activePatientId = '';
  List<Map<String, dynamic>> _allRecords = [];
  String _selectedFilter =
      'All'; // 'All', 'Prescriptions', 'Lab Reports', 'Scans'

  @override
  void initState() {
    super.initState();
    _activePatientId = widget.patientId.trim();
    _initAndFetch();
  }

  Future<void> _initAndFetch() async {
    // 1. Resolve Patient ID from session or phone search if missing
    if (_activePatientId.isEmpty ||
        _activePatientId == '--' ||
        _activePatientId == '1') {
      try {
        final prefs = await SharedPreferences.getInstance();
        final storedId = prefs.getString('session_patient_id') ?? '';
        final storedPhone = prefs.getString('session_phone') ?? '';

        if (storedId.isNotEmpty && storedId != '--' && storedId != '1') {
          _activePatientId = storedId;
        } else if (storedPhone.isNotEmpty) {
          final searchRes = await http
              .get(
                Uri.parse(ApiConfig.patientSearch(storedPhone)),
                headers: {
                  'X-Hospital-Branch': widget.location,
                  'Accept': 'application/json',
                  if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
                },
              )
              .timeout(const Duration(seconds: 8));

          if (searchRes.statusCode == 200) {
            final json = jsonDecode(searchRes.body);
            dynamic pList = json['data'];
            if (pList is Map && pList.containsKey('data'))
              pList = pList['data'];
            if (pList is List && pList.isNotEmpty) {
              for (var p in pList) {
                final pPhone = (p['phone']?.toString() ?? '').replaceAll(
                  RegExp(r'\D'),
                  '',
                );
                if (pPhone == storedPhone ||
                    pPhone.endsWith(storedPhone) ||
                    storedPhone.endsWith(pPhone)) {
                  final foundId = (p['patient_id'] ?? p['id'] ?? '')
                      .toString()
                      .trim();
                  if (foundId.isNotEmpty) {
                    _activePatientId = foundId;
                    await prefs.setString('session_patient_id', foundId);
                    break;
                  }
                }
              }
              if (_activePatientId.isEmpty) {
                final firstId =
                    (pList.first['patient_id'] ?? pList.first['id'] ?? '')
                        .toString()
                        .trim();
                if (firstId.isNotEmpty) {
                  _activePatientId = firstId;
                  await prefs.setString('session_patient_id', firstId);
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error resolving patient ID: $e');
      }
    }

    if (mounted) setState(() {});
    await _fetchPrescriptions();
  }

  Future<void> _fetchPrescriptions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      final pid = _activePatientId.trim();
      final headers = {
        'X-Hospital-Branch': widget.location,
        'Accept': 'application/json',
        if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
      };

      List<Map<String, dynamic>> records = [];

      // 1. Primary endpoint: /prescriptions/patient/{patient_id}
      if (pid.isNotEmpty && pid != '--') {
        final res = await http
            .get(
              Uri.parse(ApiConfig.patientPrescriptions(pid)),
              headers: headers,
            )
            .timeout(const Duration(seconds: 12));

        if (res.statusCode == 200) {
          final json = jsonDecode(res.body);
          if (json['data'] != null) {
            final data = json['data'];

            // A. Consultation Prescriptions (history)
            if (data is Map && data['history'] is List) {
              for (var h in data['history']) {
                if (h is Map) {
                  final m = Map<String, dynamic>.from(h);
                  m['category'] = 'Prescriptions';
                  records.add(m);
                }
              }
            }

            // B. Radiology Reports & Brain/Body Scans
            if (data is Map && data['radiology_reports'] is List) {
              for (var r in data['radiology_reports']) {
                if (r is Map) {
                  final m = Map<String, dynamic>.from(r);
                  m['category'] = 'Scans';
                  m['prescription_id'] =
                      m['result_id'] ??
                      m['order_id'] ??
                      'SCAN-${records.length + 1}';
                  m['prescription_date'] = m['result_date'] ?? m['created_at'];
                  m['doctor_name'] =
                      m['radiologist'] ??
                      m['reviewed_by_name'] ??
                      'Radiologist';
                  m['department'] = m['modality'] ?? 'Radiology & Imaging';
                  m['diagnosis'] = m['test_name'] ?? 'Diagnostic Scan';
                  m['prescription_pdf'] = m['report_file'];
                  records.add(m);
                }
              }
            }

            // C. Pathology Lab Reports
            if (data is Map && data['lab_reports'] is List) {
              for (var l in data['lab_reports']) {
                if (l is Map) {
                  final m = Map<String, dynamic>.from(l);
                  m['category'] = 'Lab Reports';
                  m['prescription_id'] =
                      m['result_id'] ??
                      m['order_id'] ??
                      'LAB-${records.length + 1}';
                  m['prescription_date'] = m['result_date'] ?? m['created_at'];
                  m['doctor_name'] =
                      m['reviewed_by_name'] ??
                      m['reviewed_by'] ??
                      'Pathologist';
                  m['department'] = 'Clinical Pathology Lab';
                  m['diagnosis'] = m['test_name'] ?? 'Laboratory Investigation';
                  m['prescription_pdf'] = m['report_file'];
                  records.add(m);
                }
              }
            }

            // D. Flat List fallback
            if (data is List) {
              for (var item in data) {
                if (item is Map) {
                  final m = Map<String, dynamic>.from(item);
                  m['category'] = 'Prescriptions';
                  records.add(m);
                }
              }
            }
          }
        }
      }

      // 2. Secondary fallback: /consultations?patient_id={pid}
      if (records.isEmpty && pid.isNotEmpty) {
        final consultRes = await http
            .get(
              Uri.parse('${ApiConfig.consultations}?patient_id=$pid'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 8));

        if (consultRes.statusCode == 200) {
          final cJson = jsonDecode(consultRes.body);
          final cList = (cJson['data'] ?? []) as List;
          for (var c in cList) {
            if (c is Map) {
              final m = Map<String, dynamic>.from(c);
              m['category'] = 'Prescriptions';
              records.add(m);
            }
          }
        }
      }

      // Sort all records by date descending (latest first)
      records.sort((a, b) {
        final dateA =
            DateTime.tryParse(
              '${a['prescription_date'] ?? a['consultation_date'] ?? a['result_date'] ?? a['date'] ?? ''}',
            ) ??
            DateTime(2000);
        final dateB =
            DateTime.tryParse(
              '${b['prescription_date'] ?? b['consultation_date'] ?? b['result_date'] ?? b['date'] ?? ''}',
            ) ??
            DateTime(2000);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _allRecords = records;
          _isLoading = false;
        });
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

  void _openPrescriptionPdf(Map<String, dynamic> item) {
    HapticFeedback.mediumImpact();
    final pdfUrl = PrescriptionsScreen.resolvePdfUrl(item);

    if (pdfUrl.isNotEmpty) {
      HospitalContact.openWebsite(pdfUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Opening official PDF document..."),
          backgroundColor: _kPrimary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // If server has not yet attached PDF, open detailed Rx slip
      _showPrescriptionDetailModal(item);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Digital Rx slip shown. Consultant has not attached a PDF file yet.",
          ),
          backgroundColor: _kPrimaryDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPrescriptionDetailModal(Map<String, dynamic> item) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PrescriptionDetailSheet(
        item: item,
        patientName: widget.userName,
        patientId: _activePatientId,
        location: widget.location,
        onOpenPdf: () => _openPrescriptionPdf(item),
      ),
    );
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return 'Date: --';
    final str = dateVal.toString().trim();
    if (str.isEmpty) return 'Date: --';
    try {
      final dt = DateTime.parse(str);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return str;
    }
  }

  List<Map<String, dynamic>> get _filteredRecords {
    if (_selectedFilter == 'All') return _allRecords;
    return _allRecords.where((r) => r['category'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final prescriptionsCount = _allRecords
        .where((r) => r['category'] == 'Prescriptions')
        .length;
    final scansCount = _allRecords
        .where((r) => r['category'] == 'Scans')
        .length;
    final labsCount = _allRecords
        .where((r) => r['category'] == 'Lab Reports')
        .length;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _kPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Prescriptions & Reports",
              style: TextStyle(
                color: _kPrimaryDark,
                fontWeight: FontWeight.w900,
                fontSize: 17,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              _activePatientId.isNotEmpty
                  ? "UHID / Patient ID: $_activePatientId"
                  : "Live Hospital Records",
              style: const TextStyle(
                color: _kTextMuted,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _kPrimary),
            tooltip: "Refresh Prescriptions",
            onPressed: _fetchPrescriptions,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          if (_allRecords.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildFilterChip('All', _allRecords.length),
                  const SizedBox(width: 8),
                  if (prescriptionsCount > 0) ...[
                    _buildFilterChip('Prescriptions', prescriptionsCount),
                    const SizedBox(width: 8),
                  ],
                  if (scansCount > 0) ...[
                    _buildFilterChip(
                      'Scans',
                      scansCount,
                      label: 'Scans & Radiology',
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (labsCount > 0) ...[
                    _buildFilterChip('Lab Reports', labsCount),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchPrescriptions,
              color: _kPrimary,
              backgroundColor: Colors.white,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _kPrimary),
                    )
                  : _errorMsg.isNotEmpty
                  ? _buildErrorView()
                  : _filteredRecords.isEmpty
                  ? _buildEmptyView()
                  : _buildPrescriptionList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, int count, {String? label}) {
    final isSel = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSel ? _kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSel ? _kPrimary : _kBorder),
          boxShadow: isSel
              ? [
                  BoxShadow(
                    color: _kPrimary.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label ?? key,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSel ? FontWeight.w800 : FontWeight.w700,
                color: isSel ? Colors.white : _kTextMuted,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSel
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFF3EFE6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSel ? Colors.white : _kPrimaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionList() {
    final list = _filteredRecords;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return _buildPrescriptionCard(item, index);
      },
    );
  }

  Widget _buildPrescriptionCard(Map<String, dynamic> item, int index) {
    final rxId =
        item['prescription_id']?.toString() ??
        item['id']?.toString() ??
        'RX-${1000 + index}';
    final docName = item['doctor_name']?.toString() ?? 'Specialist Consultant';
    final dept =
        item['department']?.toString() ??
        item['specialization']?.toString() ??
        'OPD Consultation';
    final dateStr =
        item['prescription_date'] ??
        item['consultation_date'] ??
        item['result_date'] ??
        item['date'] ??
        '';
    final formattedDate = _formatDate(dateStr);
    final diagnosis =
        item['diagnosis']?.toString() ??
        item['chief_complaint']?.toString() ??
        'Routine Consultation';
    final category = item['category']?.toString() ?? 'Prescriptions';

    final pdfUrl = PrescriptionsScreen.resolvePdfUrl(item);
    final bool hasPdf =
        pdfUrl.isNotEmpty || item['has_prescription_pdf'] == true;

    // Parse medicines if available
    List<dynamic> meds = [];
    if (item['medicines'] is List) {
      meds = item['medicines'];
    } else if (item['medications'] is List) {
      meds = item['medications'];
    }

    // Determine category badge colors
    Color badgeColor;
    Color badgeBg;
    IconData typeIcon;
    String badgeText;
    if (category == 'Scans') {
      badgeColor = _kPrimaryDark;
      badgeBg = const Color(0xFFE6F4F1);
      typeIcon = Icons.document_scanner_rounded;
      badgeText = "RADIOLOGY SCAN";
    } else if (category == 'Lab Reports') {
      badgeColor = _kAccent;
      badgeBg = const Color(0xFFE6F4F1);
      typeIcon = Icons.science_rounded;
      badgeText = "LAB REPORT";
    } else {
      badgeColor = _kPrimary;
      badgeBg = const Color(0xFFE6F4F1);
      typeIcon = Icons.receipt_rounded;
      badgeText = "OPD CONSULTATION";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _kPrimaryDark.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showPrescriptionDetailModal(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(typeIcon, size: 11, color: badgeColor),
                                const SizedBox(width: 4),
                                Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: badgeColor,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3EFE6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                rxId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _kPrimaryDark,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: _kTextMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Doctor & Department Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_kPrimary, _kPrimaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _kPrimary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.medical_services_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            docName.startsWith('Dr') ? docName : 'Dr. $docName',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: _kPrimaryDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dept.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _kAccent,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF8F4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.healing_rounded,
                        size: 13,
                        color: _kPrimary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          diagnosis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _kPrimaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Action Bar (Open PDF & View Details)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meds.isNotEmpty
                            ? "${meds.length} Prescribed Med(s)"
                            : (hasPdf
                                  ? "Official PDF Attached"
                                  : "Consultation Summary"),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _kTextMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _openPrescriptionPdf(item),
                      icon: Icon(
                        hasPdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.description_rounded,
                        size: 14,
                      ),
                      label: Text(
                        hasPdf ? "Open PDF" : "View Rx Slip",
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.description_outlined,
                color: _kPrimary,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "No Medical Records Found",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _kPrimaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _activePatientId.isNotEmpty
                  ? "No e-prescriptions or lab reports recorded yet for Patient ID: $_activePatientId. They will appear here once issued by your doctor."
                  : "No prescriptions found for ${widget.userName}. Once your OPD consultation completes, records will appear here automatically.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _kTextMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchPrescriptions,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text("Refresh Records"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              "Unable to Load Records",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _kPrimaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _kTextMuted),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchPrescriptions,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detailed Modal Sheet with printable Rx Slip and PDF launch
class _PrescriptionDetailSheet extends StatelessWidget {
  final Map<String, dynamic> item;
  final String patientName;
  final String patientId;
  final String location;
  final VoidCallback onOpenPdf;

  const _PrescriptionDetailSheet({
    required this.item,
    required this.patientName,
    required this.patientId,
    required this.location,
    required this.onOpenPdf,
  });

  @override
  Widget build(BuildContext context) {
    final rxId =
        item['prescription_id']?.toString() ??
        item['id']?.toString() ??
        'RX-OPD';
    final docName = item['doctor_name']?.toString() ?? 'Specialist Consultant';
    final dept =
        item['department']?.toString() ??
        item['specialization']?.toString() ??
        'OPD Department';
    final dateStr =
        item['prescription_date'] ??
        item['consultation_date'] ??
        item['result_date'] ??
        item['date'] ??
        '';
    final diagnosis =
        item['diagnosis']?.toString() ??
        item['chief_complaint']?.toString() ??
        'OPD Consultation';
    final pdfUrl = PrescriptionsScreen.resolvePdfUrl(item);
    final hasPdf = pdfUrl.isNotEmpty || item['has_prescription_pdf'] == true;

    List<dynamic> meds = [];
    if (item['medicines'] is List) {
      meds = item['medicines'];
    } else if (item['medications'] is List) {
      meds = item['medications'];
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Medical Prescription Slip",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _kPrimaryDark,
                      ),
                    ),
                    Text(
                      "Document ID: $rxId",
                      style: const TextStyle(
                        fontSize: 11,
                        color: _kTextMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hospital Placard
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF094E54),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "GM HOSPITALS",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          location.isNotEmpty
                              ? "Branch: $location"
                              : "GM Hospitals, Bengaluru",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                "Patient: $patientName",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              patientId.isNotEmpty ? "UHID: $patientId" : "",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  // Doctor & Date
                  Row(
                    children: [
                      Expanded(
                        child: _infoBlock(
                          "Consultant Doctor",
                          docName.startsWith('Dr') ? docName : 'Dr. $docName',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _infoBlock("Specialty", dept)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _infoBlock(
                          "Document Date",
                          dateStr.isNotEmpty ? dateStr.toString() : "--",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _infoBlock("Diagnosis / Test", diagnosis),
                      ),
                    ],
                  ),

                  // Findings / Clinical Notes if present (common in CT Scans)
                  if (item['findings'] != null &&
                      item['findings'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      "CLINICAL FINDINGS",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _kPrimaryDark,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF8F4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Text(
                        item['findings'].toString().trim(),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: _kPrimaryDark,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Text(
                    "PRESCRIBED MEDICATIONS",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: _kPrimaryDark,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (meds.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF8F4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Text(
                        hasPdf
                            ? "Clinical consultation summary recorded. Please tap 'Open Official Hospital PDF' below to view and print the doctor's full digitally-signed prescription document."
                            : "Clinical consultation summary recorded. Consultant has not attached any medication items or external PDF file to this record.",
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kTextMuted,
                          height: 1.4,
                        ),
                      ),
                    )
                  else
                    ...meds.map((m) {
                      final name =
                          m['medicine_name'] ??
                          m['name'] ??
                          m['drug'] ??
                          'Medicine';
                      final dose = m['dosage'] ?? m['dose'] ?? '--';
                      final freq = m['frequency'] ?? m['timing'] ?? '--';
                      final duration = m['duration'] ?? '--';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _kPrimary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.medication_rounded,
                                size: 16,
                                color: _kPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.toString(),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: _kPrimaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "Dosage: $dose  •  Frequency: $freq  •  Duration: $duration",
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _kTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Button to Open PDF
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onOpenPdf();
                },
                icon: Icon(
                  hasPdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 20,
                ),
                label: Text(
                  hasPdf ? "Open Official Hospital PDF" : "Done",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBlock(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: _kTextMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _kPrimaryDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
