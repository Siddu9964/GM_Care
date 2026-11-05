import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows the official GM Hospitals Charter (Vision, Mission, Values)
/// and Terms & Conditions dialog.
void showHospitalCharterTermsDialog(BuildContext context) {
  HapticFeedback.lightImpact();
  showDialog(
    context: context,
    builder: (ctx) => const HospitalCharterTermsDialog(),
  );
}

class HospitalCharterTermsDialog extends StatelessWidget {
  const HospitalCharterTermsDialog({super.key});

  static const Color _kDarkGreen = Color(0xFF0E4D54);
  static const Color _kPrimaryGreen = Color(0xFF1BA6B1);
  static const Color _kVisionColor = Color(0xFF0083A4);
  static const Color _kMissionColor = Color(0xFFE85D22);
  static const Color _kValuesColor = Color(0xFF0D5E8A);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: screenHeight * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Header Bar
              _buildTopHeader(context),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Official Hospital Placard (Vision, Mission, Values)
                      _buildHospitalCharterCard(),
                      const SizedBox(height: 20),

                      // Terms & Conditions Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: _kPrimaryGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.description_outlined,
                              size: 16,
                              color: _kPrimaryGreen,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Terms & Conditions",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: _kDarkGreen,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Terms Clauses
                      _buildClauseItem(
                        number: "1",
                        title: "Hospital Entity & Authority",
                        body:
                            "GM HOSPITALS is a unit of Pan Nagarabhavi Hospitals Pvt Ltd. GM Care is the authorized patient engagement application provided to facilitate healthcare access, appointment scheduling, and health records management.",
                      ),
                      _buildClauseItem(
                        number: "2",
                        title: "Evidence-Based & Compassionate Care",
                        body:
                            "In alignment with our Mission and Vision, GM Hospitals is committed to providing evidence-based, quality care to improve the patient's quality of life at an affordable price. The app facilitates access but does not substitute direct clinical examination or triage.",
                      ),
                      _buildClauseItem(
                        number: "3",
                        title: "Appointments & Doctor Availability",
                        body:
                            "All outpatient consultations booked via GM Care are scheduled into the hospital roster. Appointments are subject to attending doctor availability. In emergencies or unexpected doctor leave, the hospital concierge desk will assist with immediate rescheduling or alternate specialist consultation.",
                      ),
                      _buildClauseItem(
                        number: "4",
                        title: "Patient Information Accuracy",
                        body:
                            "Patients must provide accurate personal, contact, and clinical history information. False or misleading information may compromise patient safety and may result in service restrictions.",
                      ),
                      _buildClauseItem(
                        number: "5",
                        title: "Health Records & Confidentiality",
                        body:
                            "All medical records, diagnostic reports, and personal data accessed or stored on GM Care are encrypted and handled in strict compliance with applicable healthcare data privacy regulations.",
                      ),
                      _buildClauseItem(
                        number: "6",
                        title: "Emergency Medical Care (24x7)",
                        body:
                            "GM Care is intended for elective outpatient scheduling and records. For critical medical emergencies or trauma, please visit our 24x7 Emergency Centre directly or contact: Nagarabhavi: 080 2301 1600 / +91 99000 35235 | Basaveshwaranagar: 080 2221 1600 / +91 99000 03527 | www.gmhospitals.com.",
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Bottom Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "I Understand & Accept",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top header with Hospital Name, Entity & Close Icon
  Widget _buildTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kDarkGreen, _kPrimaryGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _kPrimaryGreen.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.local_hospital_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  "GM HOSPITALS",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _kDarkGreen,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "A Unit of Pan Nagarabhavi Hospitals Pvt Ltd",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF007E9E),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 22, color: Colors.grey),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  /// Official Hospital Placard with Vision, Mission, and Values
  Widget _buildHospitalCharterCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFDFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6E4EC), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sub-header inside Placard
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF007E9E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "HOSPITAL CHARTER",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF007E9E),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  "Pan Nagarabhavi Hospitals Pvt Ltd",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // VISION & MISSION Rows
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // VISION Card (Teal/Cyan)
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 120),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kVisionColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _kVisionColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "VISION",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "To be a leader in providing excellence quality and compassionate patient centered care",
                        style: TextStyle(
                          fontSize: 10.5,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // MISSION Card (Orange)
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 120),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kMissionColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _kMissionColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "MISSION",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Committed to provide evidence based quality care to patient to improve the quality of life at affordable price",
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // VALUES Card (Deep Blue)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kValuesColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _kValuesColor.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "VALUES",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Do for others what you would want others do for you",
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Official Hospital Contact Strip (Nagarabhavi, Website, Basaveshwaranagar)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF094E54),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF094E54).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nagarabhavi Branch (Clickable to dial)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => HospitalContact.callPhone('08023011600'),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.location_on_rounded, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    "GM Hospitals, Nagarabhavi",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: const [
                                Icon(Icons.phone_rounded, color: Colors.white70, size: 11),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    "080 2301 1600\n+91 99000 35235",
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                                Icon(Icons.phone_forwarded_rounded, color: Colors.white70, size: 10),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      width: 1,
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.white.withValues(alpha: 0.25),
                    ),

                    // Basaveshwaranagar Branch (Clickable to dial)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => HospitalContact.callPhone('08022211600'),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.location_on_rounded, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    "GM Hospitals, Basaveshwaranagar",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: const [
                                Icon(Icons.phone_rounded, color: Colors.white70, size: 11),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    "080 2221 1600\n+91 99000 03527",
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                                Icon(Icons.phone_forwarded_rounded, color: Colors.white70, size: 10),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 6),
                // Official Website Tap Handler
                GestureDetector(
                  onTap: () => HospitalContact.openWebsite('https://gmhospitals.com/'),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.language_rounded, color: Colors.white, size: 12),
                        SizedBox(width: 5),
                        Text(
                          "www.gmhospitals.com",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white70,
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(Icons.open_in_new_rounded, color: Colors.white, size: 11),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Single Terms of Service clause
  Widget _buildClauseItem({
    required String number,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

