import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

// ─────────────────────────────────────────────────────────────
//  Constants
// ─────────────────────────────────────────────────────────────
const _kGreen      = Color(0xFF1F6B4A);
const _kGreenDark  = Color(0xFF174E36);
const _kGreenLight = Color(0xFF26875B);
const _kBg         = Color(0xFFF3EFE6);
const _kBgLight    = Color(0xFFF8F6F1);

// ─────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────
String _fmtDate(String? raw, {bool long = false}) {
  if (raw == null || raw.isEmpty) return '—';
  try {
    final dt = DateTime.parse(raw);
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    if (long) return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    return '${dt.day.toString().padLeft(2,'0')} ${m[dt.month - 1]} ${dt.year}';
  } catch (_) { return raw; }
}

String _weekDay(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  try {
    final dt = DateTime.parse(raw);
    const d = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return d[dt.weekday - 1];
  } catch (_) { return ''; }
}

/// Parse soap_plan: JSON array → list of medicine maps; plain text → single raw entry
List<Map<String, dynamic>> _parseMedicines(dynamic soapPlan) {
  if (soapPlan == null) return [];
  final s = soapPlan.toString().trim();
  if (s.isEmpty) return [];
  try {
    final decoded = jsonDecode(s);
    if (decoded is List) {
      return decoded.map<Map<String, dynamic>>(
          (e) => Map<String, dynamic>.from(e)).toList();
    }
  } catch (_) {}
  return [{'name': s, '_raw': true}];
}

String _cleanName(String raw) {
  final cut = raw.indexOf('{');
  if (cut > 0) return raw.substring(0, cut).trim();
  return raw.trim();
}

IconData _medIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('tab') || n.contains('cap'))             return Icons.medication_rounded;
  if (n.contains('syp') || n.contains('syr'))             return Icons.local_drink_rounded;
  if (n.contains('inj') || n.contains('bottle') ||
      n.contains('ns')  || n.contains('iv'))               return Icons.water_drop_rounded;
  if (n.contains('drop') || n.contains('eye') ||
      n.contains('ear'))                                    return Icons.opacity_rounded;
  if (n.contains('cream') || n.contains('gel'))           return Icons.spa_rounded;
  return Icons.medication_liquid_rounded;
}

// ─────────────────────────────────────────────────────────────
//  Main Screen — Date-wise list
// ─────────────────────────────────────────────────────────────
class PharmacyScreen extends StatefulWidget {
  final String userName;
  final String location;
  final String cookie;

  const PharmacyScreen({
    super.key,
    required this.userName,
    required this.location,
    required this.cookie,
  });

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _errorMsg = '';
  List<dynamic> _consultations = [];
  Map<String, dynamic> _patientInfo = {};
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fetchData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Fetch ────────────────────────────────────────────────────
  Future<void> _fetchData() async {
    try {
      final headers = {
        'X-Hospital-Branch': widget.location,
        'Accept': 'application/json',
        if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
      };

      // 1. Find patient
      final searchRes = await http.get(
        Uri.parse(ApiConfig.patientSearch(widget.userName)), headers: headers);
      if (searchRes.statusCode != 200) throw Exception('Patient not found.');
      final patientsList =
          (jsonDecode(searchRes.body)['data']?['data'] ?? []) as List;
      if (patientsList.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final patient = patientsList[0];
      final patientId = patient['patient_id']?.toString() ?? '';
      if (patientId.isEmpty) throw Exception('Invalid Patient ID.');

      // 2. Fetch consultations
      final consultsRes = await http.get(
        Uri.parse('${ApiConfig.consultations}?patient_id=$patientId'),
        headers: headers,
      );

      // 3. Fetch doctors to map names
      final docsRes = await http.get(Uri.parse(ApiConfig.doctors), headers: headers);
      final Map<String, String> docMap = {};
      if (docsRes.statusCode == 200) {
        final docsList = (jsonDecode(docsRes.body)['data'] ?? []) as List;
        for (var d in docsList) {
          final dId = d['doctor_id']?.toString();
          final dName = d['full_name']?.toString() ?? d['doctor_name']?.toString();
          if (dId != null && dName != null) {
            docMap[dId] = dName;
          }
        }
      }
      if (consultsRes.statusCode == 200) {
        final all = (jsonDecode(consultsRes.body)['data'] ?? []) as List;
        
        // Inject doctor_name
        for (var c in all) {
          final dId = c['doctor_id']?.toString() ?? '';
          c['doctor_name'] = docMap[dId] ?? dId;
        }

        // Sort by date descending
        all.sort((a, b) {
          final da = DateTime.tryParse(a['consultation_date'] ?? '') ?? DateTime(2000);
          final db = DateTime.tryParse(b['consultation_date'] ?? '') ?? DateTime(2000);
          return db.compareTo(da);
        });
        if (mounted) {
          setState(() {
            _patientInfo = Map<String, dynamic>.from(patient);
            _consultations = all;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load prescriptions.');
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMsg = e.toString(); });
    }
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final hPad = isTablet ? size.width * 0.07 : 0.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Column(
          children: [
            _buildHeader(isTablet),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _kGreen))
                  : _errorMsg.isNotEmpty
                      ? _buildError()
                      : _consultations.isEmpty
                          ? _buildEmpty()
                          : Padding(
                              padding: EdgeInsets.symmetric(horizontal: hPad),
                              child: _buildList(isTablet),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader(bool isTablet) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGreenDark, _kGreen, _kGreenLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(right: -30, top: -30,
              child: _Circle(120, Colors.white.withOpacity(0.06))),
          Positioned(left: -20, bottom: -20,
              child: _Circle(80, Colors.white.withOpacity(0.05))),
          Positioned(right: 60, bottom: 10,
              child: _Circle(50, Colors.white.withOpacity(0.07))),

          Padding(
            padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back + Title row
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.25)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text('Pharmacy & Prescriptions',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 20),
                // Stats row
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.local_pharmacy_rounded,
                      label: '${_consultations.length}',
                      sub: 'Prescriptions',
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      icon: Icons.person_rounded,
                      label: widget.userName,
                      sub: 'Patient',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Date-wise list ───────────────────────────────────────────
  Widget _buildList(bool isTablet) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      physics: const BouncingScrollPhysics(),
      itemCount: _consultations.length,
      itemBuilder: (ctx, i) {
        final c = _consultations[i];
        final medicines = _parseMedicines(c['soap_plan']);
        final medCount  = medicines.isEmpty ? 0 :
            (medicines.length == 1 && medicines[0]['_raw'] == true) ? 1 : medicines.length;
        final date       = c['consultation_date'] ?? '';
        final doctorName = c['doctor_name']?.toString() ?? c['doctor_id']?.toString() ?? '—';
        final isFirst   = i == 0;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 350 + i * 60),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(offset: Offset(0, 30 * (1 - v)), child: child),
          ),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, a, __) => PrescriptionDetailScreen(
                  consult: c,
                  patientInfo: _patientInfo,
                  location: widget.location,
                  cookie: widget.cookie,
                ),
                transitionsBuilder: (_, a, __, child) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween<Offset>(
                        begin: const Offset(0, 0.04), end: Offset.zero)
                        .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                ),
                transitionDuration: const Duration(milliseconds: 300),
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _kGreen.withOpacity(0.07),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: isFirst
                    ? Border.all(color: _kGreen.withOpacity(0.3), width: 1.5)
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Date badge
                    _DateBadge(dateStr: date, isLatest: isFirst),
                    const SizedBox(width: 16),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isFirst) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _kGreen,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('LATEST',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5)),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Text(
                                  'Prescription · ${_fmtDate(date, long: true)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFF1A1A2E)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded,
                                  size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  doctorName.startsWith('Dr') ? doctorName : 'Dr. $doctorName',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              _SmallChip(
                                icon: Icons.medication_rounded,
                                label: '$medCount Medicine${medCount == 1 ? '' : 's'}',
                                color: _kGreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Arrow
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _kGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_forward_ios_rounded,
                          color: _kGreen, size: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        Text(_errorMsg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            setState(() { _isLoading = true; _errorMsg = ''; });
            _fetchData();
          },
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ]),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: _kGreen.withOpacity(0.08), shape: BoxShape.circle),
        child: const Icon(Icons.medication_outlined, size: 64, color: _kGreen),
      ),
      const SizedBox(height: 20),
      const Text('No Prescriptions Yet',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: _kGreen)),
      const SizedBox(height: 8),
      const Text('Your prescriptions will appear here after a consultation.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────
//  Prescription Detail Screen  (Receipt-style)
// ─────────────────────────────────────────────────────────────
class PrescriptionDetailScreen extends StatelessWidget {
  final dynamic consult;
  final Map<String, dynamic> patientInfo;
  final String location;
  final String cookie;

  const PrescriptionDetailScreen({
    super.key,
    required this.consult,
    required this.patientInfo,
    required this.location,
    required this.cookie,
  });

  @override
  Widget build(BuildContext context) {
    final size     = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final hPad     = isTablet ? size.width * 0.08 : 16.0;
    final topPad   = MediaQuery.of(context).padding.top;

    final date        = consult['consultation_date'] ?? '';
    final doctorName  = consult['doctor_name']?.toString() ?? consult['doctor_id']?.toString() ?? '—';
    final patientName = '${patientInfo['first_name'] ?? ''} ${patientInfo['last_name'] ?? ''}'.trim();
    final patientId  = patientInfo['patient_id']?.toString() ?? '—';
    final phone      = patientInfo['phone']?.toString() ?? '—';
    final medicines  = _parseMedicines(consult['soap_plan']);
    final hasRaw     = medicines.length == 1 && medicines[0]['_raw'] == true;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBgLight,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Top receipt header ─────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kGreenDark, _kGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(right: -40, top: -40,
                        child: _Circle(150, Colors.white.withOpacity(0.05))),
                    Positioned(left: -20, bottom: -30,
                        child: _Circle(100, Colors.white.withOpacity(0.06))),
                    Padding(
                      padding: EdgeInsets.fromLTRB(hPad, topPad + 14, hPad, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.25)),
                              ),
                              child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Hospital name (left) + PRESCRIPTION RECEIPT (right)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                              Icons.local_pharmacy_rounded,
                                              color: Colors.white, size: 20),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text('GM Hospital',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -0.5)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      location,
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.3)),
                                    ),
                                    child: const Text('PRESCRIPTION',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.2)),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _fmtDate(date, long: true),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ────────────────────────────────────────
            SliverPadding(
              padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // Patient Info grid (like the receipt)
                  _buildInfoCard(patientName, patientId, phone, doctorName),

                  const SizedBox(height: 20),

                  // Medicine Table
                  hasRaw
                      ? _buildRawCard(medicines.first['name'])
                      : _buildMedicineTable(medicines, isTablet),

                  const SizedBox(height: 20),

                  // Footer note
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _kGreen.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kGreen.withOpacity(0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: _kGreen, size: 18),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Please follow the prescribed dosage carefully. '
                            'Contact your doctor before stopping any medication.',
                            style: TextStyle(
                                fontSize: 12,
                                color: _kGreen,
                                fontWeight: FontWeight.w600,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Patient info card ────────────────────────────────────────
  Widget _buildInfoCard(
      String name, String pid, String phone, String doctor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
              color: _kGreen.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(bottom: BorderSide(color: _kGreen.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin_rounded, color: _kGreen, size: 18),
                const SizedBox(width: 8),
                const Text('PATIENT INFORMATION',
                    style: TextStyle(
                        color: _kGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(builder: (ctx, constraints) {
              final half = constraints.maxWidth > 400;
              final rows = [
                ['PATIENT', name.isNotEmpty ? name.toUpperCase() : '—', false],
                ['PATIENT ID', pid, true],
                ['PHONE', phone, false],
                ['DOCTOR', doctor.startsWith('Dr') ? doctor : 'Dr. $doctor', true],
              ];

              if (half) {
                // 2-column grid like receipt
                return Column(
                  children: [
                    _InfoRow2Col(rows[0] as List, rows[1] as List),
                    const SizedBox(height: 14),
                    _InfoRow2Col(rows[2] as List, rows[3] as List),
                  ],
                );
              }
              // Single column for narrow
              return Column(
                children: rows
                    .map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _InfoRowSingle(r as List),
                        ))
                    .toList(),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Medicine table ───────────────────────────────────────────
  Widget _buildMedicineTable(List<Map<String, dynamic>> meds, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
              color: _kGreen.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(bottom: BorderSide(color: _kGreen.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                const Icon(Icons.medication_rounded, color: _kGreen, size: 18),
                const SizedBox(width: 8),
                Text('MEDICINES  ·  ${meds.length} ITEM${meds.length == 1 ? '' : 'S'}',
                    style: const TextStyle(
                        color: _kGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8)),
              ],
            ),
          ),

          // Column labels row (receipt-style)
          Container(
            color: _kGreen,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Row(
              children: [
                SizedBox(width: 30, child: Text('#',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 12))),
                Expanded(flex: 5, child: Text('MEDICINE',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 12))),
                Expanded(flex: 3, child: Text('DOSAGE / FREQ',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 12))),
                Expanded(flex: 2, child: Text('DURATION',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 12))),
              ],
            ),
          ),

          // Medicine rows
          ...List.generate(meds.length, (i) {
            final med      = meds[i];
            final name     = _cleanName(med['name']?.toString() ?? '—');
            final dosage   = med['dosage']?.toString() ?? '—';
            final freq     = med['freq']?.toString() ?? '—';
            final duration = med['duration']?.toString() ?? '—';
            final isEven   = i % 2 == 0;

            return Container(
              decoration: BoxDecoration(
                color: isEven ? Colors.white : _kGreen.withOpacity(0.025),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.withOpacity(0.08)),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Index
                  SizedBox(
                    width: 30,
                    child: Container(
                      width: 22, height: 22,
                      decoration: const BoxDecoration(
                          color: _kGreen, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  // Name + icon
                  Expanded(
                    flex: 5,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(_medIcon(name), color: _kGreen, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF1A1A2E)),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  // Dosage / Freq
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(dosage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF444444))),
                        if (freq != '—') ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(freq,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: _kGreen)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Duration
                  Expanded(
                    flex: 2,
                    child: Text(duration,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF444444))),
                  ),
                ],
              ),
            );
          }),

          // Footer summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.04),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: _kGreen, size: 16),
                const SizedBox(width: 8),
                Text('${meds.length} medicine${meds.length == 1 ? '' : 's'} prescribed',
                    style: const TextStyle(
                        fontSize: 12,
                        color: _kGreen,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawCard(String text) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGreen.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
              color: _kGreen.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(bottom: BorderSide(color: _kGreen.withOpacity(0.1))),
            ),
            child: Row(children: const [
              Icon(Icons.notes_rounded, color: _kGreen, size: 18),
              SizedBox(width: 8),
              Text('TREATMENT PLAN',
                  style: TextStyle(
                      color: _kGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13, height: 1.7, color: Color(0xFF333333))),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Reusable small widgets
// ─────────────────────────────────────────────────────────────

class _DateBadge extends StatelessWidget {
  final String dateStr;
  final bool isLatest;
  const _DateBadge({required this.dateStr, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    String day = '—', mon = '—', yr = '';
    try {
      final dt = DateTime.parse(dateStr);
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
      day = dt.day.toString().padLeft(2, '0');
      mon = m[dt.month - 1].toUpperCase();
      yr  = dt.year.toString();
    } catch (_) {}

    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isLatest ? _kGreen : _kGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(mon, style: TextStyle(
              color: isLatest ? Colors.white70 : Colors.grey,
              fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(day, style: TextStyle(
              color: isLatest ? Colors.white : _kGreen,
              fontSize: 22, fontWeight: FontWeight.w900, height: 1.0)),
          const SizedBox(height: 2),
          Text(yr, style: TextStyle(
              color: isLatest ? Colors.white60 : Colors.grey,
              fontSize: 9, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  const _StatChip({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14)),
              Text(sub,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SmallChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

// 2-column info row like a receipt
class _InfoRow2Col extends StatelessWidget {
  final List leftData, rightData;
  const _InfoRow2Col(this.leftData, this.rightData);

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _InfoCell(leftData[0] as String, leftData[1] as String,
              leftData[2] as bool)),
          const SizedBox(width: 12),
          Expanded(child: _InfoCell(rightData[0] as String, rightData[1] as String,
              rightData[2] as bool)),
        ],
      );
}

class _InfoRowSingle extends StatelessWidget {
  final List data;
  const _InfoRowSingle(this.data);

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(data[0] as String,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                    letterSpacing: 0.3)),
          ),
          Expanded(
            child: Text(data[1] as String,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: (data[2] as bool) ? _kGreen : const Color(0xFF1A1A2E))),
          ),
        ],
      );
}

class _InfoCell extends StatelessWidget {
  final String label, value;
  final bool accent;
  const _InfoCell(this.label, this.value, this.accent);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: accent ? _kGreen : const Color(0xFF1A1A2E)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      );
}

class _Circle extends StatelessWidget {
  final double size;
  final Color color;
  const _Circle(this.size, this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}
