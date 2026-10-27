import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/api_config.dart';
import '../widgets/appointment_form_sheet.dart';

import 'patient_dashboard.dart';

class SpecialistDoctorsScreen extends StatefulWidget {
  final String specialization;
  final List<dynamic> doctors;
  final String userName;
  final String location;
  final String age;
  final String sex;
  final String cookie;
  final String patientId;

  const SpecialistDoctorsScreen({
    super.key,
    required this.specialization,
    required this.doctors,
    required this.userName,
    required this.location,
    required this.age,
    required this.sex,
    required this.cookie,
    this.patientId = '',
  });

  @override
  State<SpecialistDoctorsScreen> createState() => _SpecialistDoctorsScreenState();
}

class _SpecialistDoctorsScreenState extends State<SpecialistDoctorsScreen> {
  String _searchQuery = "";
  String _selectedCategory = "All";
  List<String> _categories = ["All"];

  @override
  void initState() {
    super.initState();
    // Extract unique departments for the chips
    final Set<String> depts = {};
    for (var d in widget.doctors) {
      final dept = d['department']?.toString().trim();
      if (dept != null && dept.isNotEmpty) {
        depts.add(dept);
      }
    }
    final sortedDepts = depts.toList()..sort();
    _categories.addAll(sortedDepts);
  }

  List<dynamic> get _filteredDoctors {
    return widget.doctors.where((doc) {
      final name = (doc['full_name'] ?? '').toString().toLowerCase();
      final spec = (doc['specialization'] ?? '').toString().toLowerCase();
      final dept = (doc['department'] ?? '').toString().trim();
      
      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || spec.contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == "All" || dept == _selectedCategory;
      
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredDoctors;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F1), // Cream background matching image perfectly
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header (Arrow, Title, Count Badge)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
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
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))
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
                          "Our Specialists",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "PREMIUM HEALTHCARE NETWORK",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF1F6B4A).withOpacity(0.5), letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F6B4A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${filteredList.length} Doctors",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(27),
                  border: Border.all(color: Colors.grey.shade200, width: 1.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: "Search by name or specialty...",
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600, fontSize: 15),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(color: Color(0xFF1F6B4A), fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                    Icon(Icons.tune_rounded, color: Colors.grey.shade500, size: 22),
                  ],
                ),
              ),
            ),

            // 3. Category Chips
            SizedBox(
              height: 40,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF065F46) : const Color(0xFFEDE9DD),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected 
                          ? [BoxShadow(color: const Color(0xFF065F46).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                          : [],
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 4. Doctor Cards List
            Expanded(
              child: filteredList.isEmpty
                  ? Center(
                      child: Text(
                        "No doctors found.",
                        style: TextStyle(fontWeight: FontWeight.w800, color: const Color(0xFF1F6B4A).withOpacity(0.5), fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        return _buildDoctorCard(context, filteredList[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, dynamic doc) {
    String name = doc['full_name'] ?? 'Unknown Doctor';
    if (!name.toLowerCase().startsWith('dr.')) {
      name = 'Dr. $name';
    }
    final spec = doc['specialization'] ?? '';
    final department = doc['department'] ?? '';
    final fee = doc['consultation_fee'] ?? 'N/A';
    
    // Format timings safely
    final inTimeRaw = doc['in_time']?.toString() ?? '';
    final outTimeRaw = doc['out_time']?.toString() ?? '';
    String timings = 'Not Available';
    if (inTimeRaw.isNotEmpty && outTimeRaw.isNotEmpty) {
       try {
         final inParts = inTimeRaw.split(':');
         final outParts = outTimeRaw.split(':');
         int inH = int.parse(inParts[0]);
         String inAmPm = inH >= 12 ? 'PM' : 'AM';
         if (inH > 12) inH -= 12;
         if (inH == 0) inH = 12;
         
         int outH = int.parse(outParts[0]);
         String outAmPm = outH >= 12 ? 'PM' : 'AM';
         if (outH > 12) outH -= 12;
         if (outH == 0) outH = 12;
         
         timings = '$inH:${inParts[1]} $inAmPm - $outH:${outParts[1]} $outAmPm';
       } catch (e) {
         timings = '$inTimeRaw - $outTimeRaw';
       }
    }

    final availability = doc['availability']?.toString() ?? 'Off-Duty';
    final isAvailable = availability.toLowerCase() == 'available';
    
    String photoUrl = doc['photo'] != null && doc['photo'].toString().isNotEmpty
        ? ApiConfig.imageBaseUrl + doc['photo']
        : "https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=1F6B4A&color=F3EFE6&bold=true";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F6B4A).withOpacity(0.04), 
            blurRadius: 20, 
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with online indicator
          Stack(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(photoUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (isAvailable)
                Positioned(
                  bottom: 2,
                  right: 4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981), // Bright green indicator matching image
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF334155), letterSpacing: -0.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  department.isNotEmpty ? "${spec.toUpperCase()} • ${department.toUpperCase()}" : spec.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF059669), letterSpacing: 0.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Text(timings, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.currency_rupee_rounded, size: 14, color: Color(0xFFB45309)),
                    const SizedBox(width: 4),
                    Text("Fee: ₹$fee", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFB45309))),
                  ],
                ),
              ],
            ),
          ),
          
          // Right Side Book Button Pill
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Padding(
                  padding: EdgeInsets.only(
                    left: 16, 
                    right: 16, 
                    top: 60, 
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: AppointmentFormSheet(
                      userName: widget.userName,
                      location: widget.location,
                      age: widget.age,
                      sex: widget.sex,
                      cookie: widget.cookie,
                      patientId: widget.patientId,
                      initialDepartment: department,
                      initialDoctorName: doc['full_name'],
                      onClose: () => Navigator.pop(context),
                      onSuccess: () => Navigator.pop(context),
                    ),
                  ),
                ),
              );
            },
            child: Container(
              width: 52,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF3EFE6), // Beige pill
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.chevron_right_rounded, color: Color(0xFF334155), size: 22),
                  SizedBox(height: 4),
                  Text("BOOK", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF334155))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
