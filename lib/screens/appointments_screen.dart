import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../widgets/appointment_form_sheet.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../services/notification_service.dart';
import 'patient_dashboard.dart';
import 'account_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  final String userName;
  final String location;
  final String age;
  final String sex;
  final String cookie;
  final String patientId;
  final int initialTab;

  const AppointmentsScreen({
    super.key,
    required this.userName,
    required this.location,
    required this.age,
    required this.sex,
    required this.cookie,
    this.patientId = '',
    this.initialTab = 0,
  });

  static String normalizeDoctor(dynamic apt) {
    if (apt is! Map) return '';
    final name = (apt['doctor_name'] ?? '').toString().trim().toLowerCase();
    final clean = name.replaceFirst(RegExp(r'^(dr\.?|doctor|prof\.?)\s*'), '').trim();
    if (clean.isNotEmpty) return clean;
    return (apt['doctor_id'] ?? '').toString().trim().toLowerCase();
  }

  static String normalizeDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '';
    final trimmed = dateStr.trim();
    try {
      final dt = DateTime.tryParse(trimmed);
      if (dt != null) {
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    return trimmed.toLowerCase();
  }

  static String normalizeTime(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return '';
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final timeOnly = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = timeOnly.split(':');
      if (parts.length >= 2) {
        int h = int.parse(parts[0].trim());
        int m = int.parse(parts[1].trim());
        if (isPm && h < 12) h += 12;
        if (isAm && h == 12) h = 0;
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    return timeStr.trim().toLowerCase();
  }

  /// Deduplicates appointment list by unique appointment_id AND composite slot key (doctor + date + time).
  /// Preserves scheduled/confirmed entries over cancelled ones and guarantees exactly ONE card per booking slot.
  static List<dynamic> deduplicate(List<dynamic> list) {
    if (list.isEmpty) return [];

    final sorted = List<dynamic>.from(list);
    sorted.sort((a, b) {
      if (a is! Map || b is! Map) return 0;
      final statusA = (a['status'] ?? a['appointment_status'] ?? '').toString().toLowerCase();
      final statusB = (b['status'] ?? b['appointment_status'] ?? '').toString().toLowerCase();
      final isAActive = statusA != 'cancelled' && statusA != 'doctor on leave';
      final isBActive = statusB != 'cancelled' && statusB != 'doctor on leave';
      if (isAActive && !isBActive) return -1;
      if (!isAActive && isBActive) return 1;
      return 0;
    });

    final List<dynamic> result = [];
    final Set<String> seenIds = {};
    final Set<String> seenSlots = {};

    for (var item in sorted) {
      if (item is! Map) continue;
      final apt = item;

      // 1. Check Unique Appointment ID
      final id = (apt['appointment_id'] ?? apt['id'] ?? '').toString().trim().toLowerCase();
      if (id.isNotEmpty && seenIds.contains(id)) {
        continue; // duplicate by unique ID
      }

      // 2. Check Booking Slot Key (Doctor + Date + Time)
      final docKey = normalizeDoctor(apt);
      final dateKey = normalizeDate(apt['appointment_date']?.toString());
      final timeKey = normalizeTime(apt['appointment_time']?.toString());
      final slotKey = '$docKey|$dateKey|$timeKey';

      if (docKey.isNotEmpty && dateKey.isNotEmpty && timeKey.isNotEmpty) {
        if (seenSlots.contains(slotKey)) {
          continue; // duplicate booking slot! Keep only ONE card
        }
        seenSlots.add(slotKey);
      }

      if (id.isNotEmpty) {
        seenIds.add(id);
      }

      result.add(apt);
    }

    return result;
  }

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // State for My Appointments
  bool _isLoading = true;
  String _errorMsg = '';
  List<dynamic> _appointments = [];
  String _activeFilter = 'All'; // 'All', 'Scheduled', 'Completed', 'Cancelled'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this, 
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _fetchAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAppointments() async {
    if (!mounted) return;
    if (_appointments.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMsg = '';
      });
    }
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.appointments}?search=${Uri.encodeComponent(widget.userName)}'),
        headers: {
          'X-Hospital-Branch': widget.location,
          'Accept': 'application/json',
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['status'] == 'success' && json['data'] != null) {
          final List rawList;
          if (json['data'] is List) {
            rawList = json['data'];
          } else if (json['data'] is Map && json['data']['data'] is List) {
            rawList = json['data']['data'];
          } else {
            rawList = [];
          }
          final deduplicated = AppointmentsScreen.deduplicate(rawList);
          setState(() {
            _appointments = deduplicated;
            _isLoading = false;
            _errorMsg = '';
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() {
          _isLoading = false;
          if (_appointments.isEmpty) {
            _errorMsg = "Server error (${response.statusCode})";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_appointments.isEmpty) {
            _errorMsg = e.toString();
          }
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

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "Unknown Time";
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        int h = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        String ampm = h >= 12 ? 'PM' : 'AM';
        if (h > 12) h -= 12;
        if (h == 0) h = 12;
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
      }
    } catch (_) {}
    return timeStr;
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Scheduled', 'Completed', 'Cancelled'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _activeFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => setState(() => _activeFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1BA6B1) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF1BA6B1) : const Color(0xFFDED8CB),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1BA6B1).withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF5A6E64),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getDoctorInitial(String rawName) {
    String n = rawName.trim();
    n = n.replaceFirst(RegExp(r'^(dr\.?|doctor|prof\.?)\s*', caseSensitive: false), '').trim();
    if (n.isEmpty) {
      n = rawName.replaceAll(RegExp(r'[^a-zA-Z]'), '').trim();
    }
    for (int i = 0; i < n.length; i++) {
      final c = n[i];
      if (RegExp(r'[a-zA-Z]').hasMatch(c)) {
        return c.toUpperCase();
      }
    }
    return 'D';
  }

  Color _getDoctorColor(String initial) {
    const colors = [
      Color(0xFF0E4D54), // Forest Emerald
      Color(0xFF0F766E), // Clinical Teal
      Color(0xFF1D4ED8), // Sapphire Blue
      Color(0xFF6D28D9), // Deep Violet
      Color(0xFFB45309), // Warm Amber
      Color(0xFFBE123C), // Crimson Red
      Color(0xFF4338CA), // Royal Indigo
      Color(0xFF0E4D54), // Forest Emerald
      Color(0xFF0E7490), // Ocean Cyan
    ];
    if (initial.isEmpty) return colors[0];
    final code = initial.codeUnitAt(0);
    return colors[code % colors.length];
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HOSPITAL FEATURES: LEAVE NOTICE, RESCHEDULE, CANCEL, CALENDAR
  // ─────────────────────────────────────────────────────────────────────────

  bool _isLeaveBannerDismissed = false;

  void _switchToBookTab(String doctorName, String? department) {
    _tabController.animateTo(1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Booking consultation with $doctorName"),
        backgroundColor: const Color(0xFF1BA6B1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _toDbTime(String slot) {
    try {
      final clean = slot.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final timeOnly = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = timeOnly.split(':');
      if (parts.length >= 2) {
        int h = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        if (isPm && h < 12) h += 12;
        if (isAm && h == 12) h = 0;
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
      }
    } catch (_) {}
    return '10:30:00';
  }

  void _showRescheduleSheet(BuildContext context, dynamic apt) {
    final aptId = apt['id']?.toString() ?? apt['appointment_id']?.toString() ?? '101';
    final docName = apt['doctor_name'] ?? 'Consultant';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String selectedSlot = '10:30 AM';

    final slots = ['09:30 AM', '10:30 AM', '11:45 AM', '02:30 PM', '04:00 PM', '05:30 PM'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1BA6B1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF1BA6B1), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Reschedule Appointment",
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0E4D54))),
                        Text("With $docName",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF5A6E64))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text("Select New Date", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0E4D54))),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 10,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final d = DateTime.now().add(Duration(days: i + 1));
                    final isSel = selectedDate.day == d.day && selectedDate.month == d.month;
                    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedDate = d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF1BA6B1) : const Color(0xFFFBF8F4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSel ? const Color(0xFF1BA6B1) : const Color(0xFFDED8CB)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(days[d.weekday - 1],
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isSel ? Colors.white70 : const Color(0xFF5A6E64))),
                            Text("${d.day}",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isSel ? Colors.white : const Color(0xFF0E4D54))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text("Select Time Slot", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0E4D54))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: slots.map((s) {
                  final isSel = selectedSlot == s;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedSlot = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF1BA6B1) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSel ? const Color(0xFF1BA6B1) : const Color(0xFFDED8CB)),
                      ),
                      child: Text(s,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isSel ? Colors.white : const Color(0xFF0E4D54))),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    HapticFeedback.mediumImpact();
                    final formattedDate = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
                    final dbTime = _toDbTime(selectedSlot);
                    
                    // 1. UPDATE STATE IMMEDIATELY (0ms INSTANT UPDATE!)
                    setState(() {
                      apt['appointment_date'] = formattedDate;
                      apt['appointment_time'] = dbTime;
                      apt['appointment_status'] = 'Scheduled';
                      apt['status'] = 'Scheduled';
                      
                      for (var a in _appointments) {
                        final aId = a['id']?.toString() ?? a['appointment_id']?.toString();
                        if (aId == aptId) {
                          a['appointment_date'] = formattedDate;
                          a['appointment_time'] = dbTime;
                          a['appointment_status'] = 'Scheduled';
                          a['status'] = 'Scheduled';
                        }
                      }
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Rescheduled to $formattedDate at $selectedSlot!"),
                        backgroundColor: const Color(0xFF1BA6B1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );

                    // 2. Background database update
                    try {
                      await http.put(
                        Uri.parse('${ApiConfig.appointments}/$aptId'),
                        headers: {
                          'Content-Type': 'application/json',
                          'X-Hospital-Branch': widget.location,
                          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
                        },
                        body: jsonEncode({
                          'appointment_date': formattedDate,
                          'appointment_time': dbTime,
                          'appointment_status': 'Scheduled',
                          'status': 'Scheduled',
                        }),
                      );
                    } catch (_) {}
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1BA6B1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Confirm Reschedule",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, dynamic apt) {
    final aptId = apt['id']?.toString() ?? apt['appointment_id']?.toString() ?? '101';
    final docName = apt['doctor_name'] ?? 'Consultant';
    String selectedReason = 'Personal Emergency';
    final reasons = [
      'Personal Emergency',
      'Doctor Unavailable',
      'Feeling Better / Recovery',
      'Travel / Out of Town',
      'Other Reason',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 8),
              Text("Cancel Appointment", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0E4D54))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Are you sure you want to cancel consultation with $docName?",
                  style: const TextStyle(fontSize: 13, color: Color(0xFF5A6E64))),
              const SizedBox(height: 14),
              const Text("Select Reason:", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0E4D54))),
              const SizedBox(height: 6),
              ...reasons.map((r) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(r, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    value: r,
                    groupValue: selectedReason,
                    activeColor: const Color(0xFFDC2626),
                    onChanged: (v) { if (v != null) setDlgState(() => selectedReason = v); },
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Keep Slot", style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF5A6E64))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                HapticFeedback.mediumImpact();
                try {
                  await http.put(
                    Uri.parse('${ApiConfig.appointments}/$aptId'),
                    headers: {
                      'Content-Type': 'application/json',
                      'X-Hospital-Branch': widget.location,
                      if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
                    },
                    body: jsonEncode({'status': 'Cancelled', 'cancellation_reason': selectedReason}),
                  );
                } catch (_) {}

                setState(() {
                  apt['status'] = 'Cancelled';
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Appointment with $docName cancelled. Token released."),
                    backgroundColor: const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Confirm Cancel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncToCalendar(BuildContext context, dynamic apt) async {
    final docName = apt['doctor_name'] ?? 'Consultant';
    final dateStr = apt['appointment_date']?.toString() ?? '';
    final timeStr = apt['appointment_time']?.toString() ?? '10:00:00';
    final aptId = apt['id']?.toString() ?? apt['appointment_id']?.toString() ?? '101';
    final tokenNo = (int.tryParse(aptId) ?? 101) % 40 + 1;
    final formattedDate = _formatDate(dateStr);
    final formattedTime = _formatTime(timeStr);

    DateTime startDt = DateTime.now().add(const Duration(hours: 2));
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        int y = int.parse(parts[0]);
        int m = int.parse(parts[1]);
        int d = int.parse(parts[2]);
        int h = 10;
        int min = 0;
        final timeParts = timeStr.split(':');
        if (timeParts.isNotEmpty) h = int.tryParse(timeParts[0]) ?? 10;
        if (timeParts.length > 1) {
          final cleanMin = timeParts[1].replaceAll(RegExp(r'[^0-9]'), '');
          min = int.tryParse(cleanMin) ?? 0;
        }
        if (timeStr.toLowerCase().contains('pm') && h < 12) h += 12;
        if (timeStr.toLowerCase().contains('am') && h == 12) h = 0;
        startDt = DateTime(y, m, d, h, min);
      }
    } catch (_) {}

    final endDt = startDt.add(const Duration(minutes: 45));
    final title = "Doctor Appointment: Dr. $docName";
    final location = "GM Hospital, ${widget.location} (Room 204)";
    final description = "Patient: ${widget.userName} • Token #$tokenNo • UHID: ${widget.patientId.isNotEmpty ? widget.patientId : 'PID-20261019-009'}";

    HapticFeedback.mediumImpact();

    bool openedNativeCalendar = false;
    try {
      const channel = MethodChannel('com.gmcare.hospital/calendar');
      final res = await channel.invokeMethod('addToCalendar', {
        'title': title,
        'location': location,
        'description': description,
        'startTime': startDt.millisecondsSinceEpoch,
        'endTime': endDt.millisecondsSinceEpoch,
      });
      openedNativeCalendar = (res == true);
    } catch (_) {}

    // Schedule 1-hour pre-departure local notification
    try {
      final notifTime = startDt.subtract(const Duration(hours: 1));
      if (notifTime.isAfter(DateTime.now())) {
        NotificationService().scheduleAppointmentReminders(
          appointmentId: int.tryParse(aptId) ?? 101,
          doctorName: docName,
          appointmentTime: startDt,
        );
      }
    } catch (_) {}

    if (openedNativeCalendar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Opened Calendar for Dr. $docName on $formattedDate!"),
          backgroundColor: const Color(0xFF1BA6B1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      Clipboard.setData(ClipboardData(text: "$title\n$location\n$description\n$formattedDate at $formattedTime"));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Appointment saved & details copied: $formattedDate at $formattedTime"),
          backgroundColor: const Color(0xFF1BA6B1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildMyAppointmentsList() {
    if (_isLoading && _appointments.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1BA6B1)));
    }
    
    if (_errorMsg.isNotEmpty && _appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 14),
            Text(_errorMsg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _fetchAppointments,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1BA6B1)),
              child: const Text("Retry", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }

    final cleanAppointments = AppointmentsScreen.deduplicate(_appointments);
    final filteredAppointments = cleanAppointments.where((apt) {
      if (_activeFilter == 'All') return true;
      final status = apt['status']?.toString() ?? 'Scheduled';
      return status.toLowerCase() == _activeFilter.toLowerCase();
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchAppointments,
      color: const Color(0xFF1BA6B1),
      child: filteredAppointments.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFDED8CB)),
                          ),
                          child: const Icon(Icons.event_note_rounded, size: 44, color: Color(0xFF1BA6B1)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No ${_activeFilter == 'All' ? '' : _activeFilter.toLowerCase()} appointments found.",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0E4D54)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        itemCount: filteredAppointments.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final apt = filteredAppointments[index];
          final docName = apt['doctor_name'] ?? 'Consultant';
          final status = apt['status'] ?? 'Scheduled';
          final date = _formatDate(apt['appointment_date']);
          final time = _formatTime(apt['appointment_time']);
          final aptId = apt['id']?.toString() ?? apt['appointment_id']?.toString() ?? '101';
          final tokenNo = (int.tryParse(aptId) ?? 101) % 40 + 1;
          
          Color statusColor;
          Color statusBgColor;
          if (status.toLowerCase() == 'completed') {
            statusColor = const Color(0xFF128790);
            statusBgColor = const Color(0xFFD2F5F8);
          } else if (status.toLowerCase() == 'cancelled') {
            statusColor = const Color(0xFF991B1B);
            statusBgColor = const Color(0xFFFEE2E2);
          } else {
            statusColor = const Color(0xFF1BA6B1);
            statusBgColor = const Color(0xFFE6F4F1);
          }
          
          bool isExpired = false;
          if (status.toLowerCase() != 'cancelled' && status.toLowerCase() != 'completed') {
            final dtStr = '${apt['appointment_date']} ${apt['appointment_time'] ?? '00:00:00'}';
            final dt = DateTime.tryParse(dtStr);
            if (dt != null && dt.isBefore(DateTime.now())) {
              isExpired = true;
            }
          }

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDED8CB)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1BA6B1).withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badge Bar: Token & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1BA6B1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "TOKEN #$tokenNo",
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isExpired ? "COMPLETED" : status.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9, 
                                  fontWeight: FontWeight.w800, 
                                  color: isExpired ? Colors.grey.shade600 : statusColor,
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
                      children: const [
                        Icon(Icons.meeting_room_outlined, size: 13, color: Color(0xFF5A6E64)),
                        SizedBox(width: 3),
                        Text(
                          "Room 204",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF5A6E64)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Doctor Info
                Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final docInitial = _getDoctorInitial(docName);
                        final avatarColor = _getDoctorColor(docInitial);
                        return Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                avatarColor,
                                Color.lerp(avatarColor, const Color(0xFF082D31), 0.35)!,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: avatarColor.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              docInitial,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            docName.startsWith("Dr") ? docName : "Dr. $docName",
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0E4D54)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "OPD CONSULTANT • SUPER SPECIALIST",
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF1596A1), letterSpacing: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Date & Time Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF8F4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDED8CB).withOpacity(0.7)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF1BA6B1)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                date,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0E4D54)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF5A6E64)),
                          const SizedBox(width: 4),
                          Text(time, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1BA6B1))),
                        ],
                      ),
                    ],
                  ),
                ),

                // FEATURE 2: Doctor Leave Notice Banner on Card (if doctor is on leave)
                if (apt['doctor_on_leave'] == true || (index == 0 && apt['status'] == 'Scheduled' && docName.contains('Rajesh'))) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "$docName is on emergency leave today",
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _switchToBookTab("Dr. Sneha Patil (Alternate)", apt['department']),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD97706),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text("Consult Alternate (Dr. Sneha)",
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _showRescheduleSheet(context, apt),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFD97706)),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text("Pick Friday Slot",
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Buttons (Reschedule, Cancel, Calendar)
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (status.toLowerCase() != 'cancelled') ...[
                      // Reschedule Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showRescheduleSheet(context, apt),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: const BorderSide(color: Color(0xFF1BA6B1), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Reschedule",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1BA6B1))),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Cancel Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showCancelDialog(context, apt),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: BorderSide(color: Colors.red.shade300, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text("Cancel",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.red.shade700)),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    // Calendar Sync Button (Direct Phone Calendar)
                    IconButton(
                      icon: const Icon(Icons.event_available_rounded, size: 20, color: Color(0xFF1BA6B1)),
                      tooltip: "Add to Phone Calendar",
                      onPressed: () => _syncToCalendar(context, apt),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF1BA6B1).withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSupportChatModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1BA6B1).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF1BA6B1), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              "GM Care Support & Help Desk",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1BA6B1)),
            ),
            const SizedBox(height: 8),
            const Text(
              "Our hospital reception and support team are available 24/7 to assist you.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.local_hospital_rounded, color: Color(0xFF1BA6B1)),
              title: const Text("GM Hospitals, Nagarabhavi", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              subtitle: const Text("080 2301 1600  •  +91 99000 35235", style: TextStyle(fontSize: 12, color: Color(0xFF1BA6B1), fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.phone_forwarded_rounded, size: 18, color: Color(0xFF1BA6B1)),
              onTap: () {
                const MethodChannel('com.gmcare.hospital/calendar').invokeMethod('openDialer', {'phone': '08023011600'});
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital_rounded, color: Color(0xFF1BA6B1)),
              title: const Text("GM Hospitals, Basaveshwaranagar", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              subtitle: const Text("080 2221 1600  •  +91 99000 03527", style: TextStyle(fontSize: 12, color: Color(0xFF1BA6B1), fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.phone_forwarded_rounded, size: 18, color: Color(0xFF1BA6B1)),
              onTap: () {
                const MethodChannel('com.gmcare.hospital/calendar').invokeMethod('openDialer', {'phone': '08022211600'});
              },
            ),
            ListTile(
              leading: const Icon(Icons.language_rounded, color: Color(0xFF1BA6B1)),
              title: const Text("Official Website", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              subtitle: const Text("www.gmhospitals.com", style: TextStyle(fontSize: 12, color: Color(0xFF1BA6B1), fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF1BA6B1)),
              onTap: () {
                HospitalContact.openWebsite('https://gmhospitals.com/');
              },
            ),
            ListTile(
              leading: const Icon(Icons.emergency_rounded, color: Colors.red),
              title: const Text("24/7 Rapid Ambulance (National)", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.red, fontSize: 13.5)),
              subtitle: const Text("108 / 112 (Toll Free)", style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.phone_forwarded_rounded, size: 18, color: Colors.red),
              onTap: () {
                const MethodChannel('com.gmcare.hospital/calendar').invokeMethod('openDialer', {'phone': '108'});
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFE6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1BA6B1), size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientDashboard(
                    userName: widget.userName,
                    location: widget.location,
                    cookie: widget.cookie,
                    age: widget.age,
                    sex: widget.sex,
                    patientId: widget.patientId,
                  ),
                ),
              );
            }
          },
        ),
        title: const Text('Appointments',
            style: TextStyle(color: Color(0xFF1BA6B1), fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Color(0xFF1BA6B1)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1BA6B1),
          indicatorWeight: 3,
          labelColor: const Color(0xFF1BA6B1),
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'My Appointments'),
            Tab(text: 'Book Appointment'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 90),
            child: TabBarView(
                            controller: _tabController,
              children: [
                Column(
                  children: [
                    _buildFilterChips(),
                    Expanded(child: _buildMyAppointmentsList()),
                  ],
                ),
                AppointmentFormSheet(
                  userName: widget.userName,
                  location: widget.location,
                  age: widget.age,
                  sex: widget.sex,
                  cookie: widget.cookie,
                  patientId: widget.patientId,
                  onClose: () => _tabController.animateTo(0),
                  onSuccess: () {
                    _tabController.animateTo(0);
                    _fetchAppointments();
                  },
                ),
              ],
            ),
          ),
          AppBottomNavBar(
            currentIndex: 1,
            onTap: (idx) {
              if (idx == 1) return;
              if (idx == 0) {
                Navigator.pushReplacement(context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => PatientDashboard(
                      userName: widget.userName,
                      location: widget.location,
                      cookie: widget.cookie,
                      age: widget.age,
                      sex: widget.sex,
                      patientId: widget.patientId,
                    ),
                    transitionDuration: const Duration(milliseconds: 80),
                    transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                  ));
              } else if (idx == 2) {
                _showSupportChatModal(context);
              } else if (idx == 3) {
                Navigator.pushReplacement(context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => AccountScreen(
                      userName: widget.userName,
                      location: widget.location,
                      cookie: widget.cookie,
                      age: widget.age,
                      sex: widget.sex,
                      patientId: widget.patientId,
                    ),
                    transitionDuration: const Duration(milliseconds: 80),
                    transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                  ));
              }
            },
          ),
        ],
      ),
    );
  }
}
