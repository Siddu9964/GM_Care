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
  final List<String> _categories = ["All"];

  @override
  void initState() {
    super.initState();
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
      backgroundColor: const Color(0xFFF3EFE6),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header (Arrow, Title, Accreditation)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFDED8CB)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1F6B4A).withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F6B4A), size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Specialist Faculty",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF143B2A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          "CENTERS OF EXCELLENCE • NABH ACCREDITED",
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF26875B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F6B4A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${filteredList.length} Doctors",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            // 2. High-Tech Clinical Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDED8CB)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1F6B4A).withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: Color(0xFF1F6B4A), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: const InputDecoration(
                          hintText: "Search doctor name, specialty, super-specialty...",
                          hintStyle: TextStyle(color: Color(0xFF8DA89C), fontWeight: FontWeight.w500, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(color: Color(0xFF143B2A), fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _searchQuery = ""),
                        child: const Icon(Icons.close_rounded, color: Color(0xFF5A6E64), size: 18),
                      ),
                  ],
                ),
              ),
            ),

            // 3. Category Filter Chips
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
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
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1F6B4A) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF1F6B4A) : const Color(0xFFDED8CB),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF1F6B4A).withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF5A6E64),
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // 4. Doctor Cards List
            Expanded(
              child: filteredList.isEmpty
                  ? Center(
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
                            child: const Icon(Icons.person_search_rounded, size: 40, color: Color(0xFF1F6B4A)),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            "No Specialists Found",
                            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF143B2A), fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Try searching with another specialty or keyword",
                            style: TextStyle(color: Color(0xFF5A6E64), fontSize: 12),
                          ),
                        ],
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
    String name = doc['full_name'] ?? 'Consultant';
    if (!name.toLowerCase().startsWith('dr.')) {
      name = 'Dr. $name';
    }
    final spec = doc['specialization'] ?? 'Super Specialist';
    final department = doc['department'] ?? 'Department';
    final fee = doc['consultation_fee'] ?? '800';
    
    // Format timings safely
    final inTimeRaw = doc['in_time']?.toString() ?? '';
    final outTimeRaw = doc['out_time']?.toString() ?? '';
    String timings = '09:00 AM - 05:00 PM';
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

    final availability = doc['availability']?.toString() ?? 'Available';
    final isAvailable = availability.toLowerCase() == 'available';
    
    String photoUrl = doc['photo'] != null && doc['photo'].toString().isNotEmpty
        ? ApiConfig.imageBaseUrl + doc['photo']
        : "https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=1F6B4A&color=F3EFE6&bold=true";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDED8CB)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F6B4A).withOpacity(0.04), 
            blurRadius: 14, 
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Avatar, Info, Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with Online Badge
              Stack(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.2), width: 1.5),
                      image: DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (isAvailable)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF26875B),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              
              // Name & Specialty Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF143B2A),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isAvailable ? const Color(0xFF26875B).withOpacity(0.1) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isAvailable ? "ACTIVE TODAY" : "OFF-DUTY",
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: isAvailable ? const Color(0xFF1F6B4A) : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      spec.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF26875B),
                        letterSpacing: 0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      department,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5A6E64),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          // Clinical info bar: Timings, Fee & Book Action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF8F4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDED8CB).withOpacity(0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF1F6B4A)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          timings,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF143B2A)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "OPD: ₹$fee",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          // Action row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
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
                          borderRadius: BorderRadius.circular(28),
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
                  icon: const Icon(Icons.calendar_today_rounded, size: 15),
                  label: const Text(
                    "Book OPD Consultation",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F6B4A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
