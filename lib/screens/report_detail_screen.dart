import 'dart:convert';
import 'package:flutter/material.dart';
import '../config/api_config.dart';

class ReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> reportData;
  final String location;
  final String cookie;

  const ReportDetailScreen({
    super.key,
    required this.reportData,
    required this.location,
    required this.cookie,
  });

  String _formatDate(String? dateStr, String? timeStr) {
    if (dateStr == null || dateStr.isEmpty) return "Unknown Date";
    try {
      DateTime dt = DateTime.parse(dateStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      String d = "${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}";
      if (timeStr != null && timeStr.isNotEmpty) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          int h = int.parse(parts[0]);
          String ampm = h >= 12 ? 'PM' : 'AM';
          if (h > 12) h -= 12;
          if (h == 0) h = 12;
          d += ", $h:${parts[1]} $ampm";
        }
      }
      return d;
    } catch (_) {
      return dateStr;
    }
  }

  Map<String, dynamic>? _parseJson(String? str) {
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str);
    } catch (_) {
      return null;
    }
  }

  String? _parseImage(dynamic imgData) {
    if (imgData == null || imgData.toString().isEmpty) return null;
    String str = imgData.toString();
    try {
      var arr = jsonDecode(str);
      if (arr is List && arr.isNotEmpty) {
        str = arr[0].toString();
      }
    } catch (_) {}
    
    str = str.replaceAll(r'\', '/');
    
    int assetIndex = str.indexOf('assets/');
    if (assetIndex != -1) {
      str = str.substring(assetIndex);
      return "${ApiConfig.imageBaseUrl}/GM_HMS/$str";
    }
    
    if (str.isEmpty || str == '[]') return null;
    str = str.replaceAll(r'D:/xampp/htdocs/GM_HMS/', '');
    str = str.replaceAll(r'd:/xampp/htdocs/gm_hms/', '');
    if (str.startsWith('/')) str = str.substring(1);
    
    return "${ApiConfig.imageBaseUrl}/GM_HMS/$str";
  }

  @override
  Widget build(BuildContext context) {
    final patientId = reportData['patient_id'] ?? 'Unknown PID';
    // Use doctor_name if available, otherwise fallback to doctor_id
    final rawDocName = reportData['doctor_name'] ?? reportData['doctor_id'] ?? 'Unknown Doctor';
    final doctorName = rawDocName.toString().trim();
    
    final consultId = reportData['consultation_id'] ?? '';
    final dateTime = _formatDate(reportData['consultation_date'], reportData['consultation_time']);
    
    final vitals = _parseJson(reportData['vital_signs']);
    final String objective = (reportData['soap_objective'] ?? '').toString();
    final String plan = (reportData['soap_plan'] ?? '').toString();
    List<dynamic>? medicines;
    try {
      final parsed = jsonDecode(plan);
      if (parsed is List) medicines = parsed;
    } catch (_) {}
    
    final prescriptionImage = _parseImage(reportData['prescription_image']);

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFE6), // Enforced Beige Canvas
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1F6B4A)),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          "Consultation Report",
          style: TextStyle(
            color: Color(0xFF1F6B4A),
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Clinical Dossier Header
            _buildDossierHeader(consultId, doctorName, patientId, dateTime),
            
            const SizedBox(height: 32),
            
            // 2. Professional Vitals Ribbon (No Grid)
            if (vitals != null && vitals.isNotEmpty) ...[
              _buildSectionTitle("VITAL SIGNS", Icons.monitor_heart_outlined),
              const SizedBox(height: 16),
              _buildVitalsRibbon(vitals),
              const SizedBox(height: 32),
            ],

            // 3. Clinical Findings
            if (objective.isNotEmpty) ...[
              _buildSectionTitle("CLINICAL FINDINGS", Icons.fact_check_outlined),
              const SizedBox(height: 16),
              _buildFindingsList(objective),
              const SizedBox(height: 32),
            ],

            // 4. Treatment Plan
            if (plan.isNotEmpty) ...[
              _buildSectionTitle(
                medicines != null ? "TREATMENT PLAN — ${medicines.length} MEDICATIONS" : "TREATMENT PLAN", 
                Icons.medication_liquid_outlined
              ),
              const SizedBox(height: 16),
              if (medicines != null) 
                _buildMedicationTable(medicines)
              else 
                _buildGeneralPlan(plan),
              const SizedBox(height: 32),
            ],

            // 5. Prescription Image
            if (prescriptionImage != null && prescriptionImage.toString().isNotEmpty) ...[
              _buildSectionTitle("DIGITAL PRESCRIPTION", Icons.document_scanner_outlined),
              const SizedBox(height: 16),
              _buildPrescriptionViewer(prescriptionImage),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF1F6B4A).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF1F6B4A)),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1F6B4A),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildDossierHeader(String consultId, String doctorName, String patientId, String dateTime) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F6B4A).withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EFE6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "ID: $consultId",
                  style: const TextStyle(color: Color(0xFF1F6B4A), fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F6B4A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.verified_rounded, color: Color(0xFF1F6B4A), size: 14),
                    SizedBox(width: 4),
                    Text("Verified", style: TextStyle(color: Color(0xFF1F6B4A), fontSize: 10, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EFE6),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.15)),
                ),
                child: const Center(child: Icon(Icons.person_outline_rounded, color: Color(0xFF1F6B4A), size: 28)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctorName.toLowerCase().startsWith("dr") ? doctorName : "Dr. $doctorName",
                      style: const TextStyle(color: Color(0xFF1F6B4A), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Consultation completed",
                      style: TextStyle(color: const Color(0xFF1F6B4A).withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EFE6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("PATIENT", style: TextStyle(color: const Color(0xFF1F6B4A).withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(patientId, style: const TextStyle(color: Color(0xFF1F6B4A), fontSize: 14, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: const Color(0xFF1F6B4A).withOpacity(0.15)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("DATE & TIME", style: TextStyle(color: const Color(0xFF1F6B4A).withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(dateTime, style: const TextStyle(color: Color(0xFF1F6B4A), fontSize: 14, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Beautiful single continuous horizontal strip instead of separated grid cards
  Widget _buildVitalsRibbon(Map<String, dynamic> vitals) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1F6B4A).withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: vitals.entries.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final mapEntry = entry.value;
              final isLast = index == vitals.length - 1;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildVitalRibbonItem(mapEntry.key, mapEntry.value.toString()),
                  if (!isLast)
                    Container(width: 1, height: 50, color: const Color(0xFF1F6B4A).withOpacity(0.1)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildVitalRibbonItem(String label, String value) {
    IconData icon;
    String l = label.toLowerCase();
    if (l.contains('bp') || l.contains('blood')) {
      icon = Icons.monitor_heart_outlined;
    } else if (l.contains('temp')) {
      icon = Icons.thermostat_outlined;
    } else if (l.contains('weight')) {
      icon = Icons.monitor_weight_outlined;
    } else if (l.contains('spo2') || l.contains('oxy')) {
      icon = Icons.air_outlined;
    } else {
      icon = Icons.health_and_safety_outlined;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1F6B4A).withOpacity(0.6), size: 16),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF1F6B4A).withOpacity(0.6), letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A), letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFindingsList(String objective) {
    final findings = objective.split(',').where((s) => s.trim().isNotEmpty).toList();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1F6B4A).withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: List.generate(findings.length, (index) {
          final isLast = index == findings.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: isLast ? null : Border(bottom: BorderSide(color: const Color(0xFF1F6B4A).withOpacity(0.05))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF1F6B4A), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    findings[index].trim(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F6B4A), height: 1.4),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMedicationTable(List<dynamic> medicines) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1F6B4A).withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: List.generate(medicines.length, (index) {
          final med = medicines[index];
          final isLast = index == medicines.length - 1;
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: isLast ? null : Border(bottom: BorderSide(color: const Color(0xFF1F6B4A).withOpacity(0.05))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EFE6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.medication_outlined, color: Color(0xFF1F6B4A), size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            med['name']?.toString() ?? 'Unknown Medication',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildMedBadge("Dosage", med['dosage']?.toString() ?? '-'),
                              const SizedBox(width: 12),
                              _buildMedBadge("Freq", med['freq']?.toString() ?? '-'),
                              const SizedBox(width: 12),
                              _buildMedBadge("Duration", med['duration']?.toString() ?? '-'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMedBadge(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF1F6B4A).withOpacity(0.6), letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3EFE6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1F6B4A)),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralPlan(String plan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1F6B4A).withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EFE6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.healing_rounded, color: Color(0xFF1F6B4A), size: 16),
              ),
              const SizedBox(width: 12),
              const Text("Care Instructions", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A))),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            plan,
            style: TextStyle(fontSize: 14, height: 1.6, color: const Color(0xFF1F6B4A).withOpacity(0.8), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionViewer(String prescriptionImage) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1F6B4A).withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.network(
              prescriptionImage, 
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1F6B4A))),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 150,
                  alignment: Alignment.center,
                  color: const Color(0xFFF3EFE6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_rounded, color: const Color(0xFF1F6B4A).withOpacity(0.4), size: 40),
                      const SizedBox(height: 8),
                      Text("Image unavailable", style: TextStyle(color: const Color(0xFF1F6B4A).withOpacity(0.6), fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
