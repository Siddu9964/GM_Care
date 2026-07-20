import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

const Color primaryDark = Color(0xFF053F2C);
const Color primaryGreen = Color(0xFF1F6B4A);
const Color backgroundBeige = Color(0xFFF3F1EC);

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _hasUpcomingAppointment = false; // Set to true when user books an appointment
  
  late ScrollController _doctorScrollController;
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _doctorScrollController = ScrollController();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _scrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_doctorScrollController.hasClients) {
        double maxScroll = _doctorScrollController.position.maxScrollExtent;
        double currentScroll = _doctorScrollController.position.pixels;
        // Shift one card width at a time roughly (card width + margin)
        double scrollAmount = MediaQuery.of(context).size.width * 0.8 + 16; 
        
        if (currentScroll >= maxScroll - scrollAmount) {
          // If we reach the end of the reasonable list, jump to start
          _doctorScrollController.jumpTo(0);
        } else {
          _doctorScrollController.animateTo(
            currentScroll + scrollAmount,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _doctorScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBeige, 
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildSearchBar(),
                const SizedBox(height: 28),
                _buildSectionTitle('Doctors', hasSeeAll: true),
                const SizedBox(height: 16),
                _buildDoctors(),
                const SizedBox(height: 28),
                _buildSectionTitle('Quick Actions', hasSeeAll: true),
                const SizedBox(height: 16),
                _buildQuickActions(),
                
                if (_hasUpcomingAppointment) ...[
                  const SizedBox(height: 28),
                  _buildSectionTitle('Upcoming Appointment', hasSeeAll: true),
                  const SizedBox(height: 16),
                  _buildUpcomingAppointmentCard(),
                ],
                
                const SizedBox(height: 28),
                _buildSectionTitle('Departments', hasSeeAll: true),
                const SizedBox(height: 16),
                _buildDepartments(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good Morning,',
              style: GoogleFonts.inter(
                color: Colors.grey[700],
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'gm_care',
              style: GoogleFonts.inter(
                color: Colors.black87,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            image: const DecorationImage(
              image: AssetImage('assetes/gm_logoo.png'),
              fit: BoxFit.cover,
            ),
          ),
        )
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.search, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Text(
            'Search doctors, drugs...',
            style: GoogleFonts.inter(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.sliders, color: primaryGreen, size: 16),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool hasSeeAll = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (hasSeeAll)
          Text(
            'See All',
            style: GoogleFonts.inter(
              color: primaryGreen,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildDoctors() {
    final List<Map<String, String>> docs = [
      {'name': 'Dr. Marcus', 'spec': 'Neurologist', 'rating': '4.9'},
      {'name': 'Dr. Elena', 'spec': 'Pediatrician', 'rating': '4.8'},
      {'name': 'Dr. John', 'spec': 'Orthopedist', 'rating': '4.7'},
      {'name': 'Dr. Lisa', 'spec': 'Cardiologist', 'rating': '4.9'},
    ];
    
    return SizedBox(
      height: 165,
      child: ListView.builder(
        controller: _doctorScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: 10000,
        itemBuilder: (context, index) {
          final docIndex = index % docs.length;
          return _buildDoctorWideCard(
            name: docs[docIndex]['name']!, 
            specialty: docs[docIndex]['spec']!,
            rating: docs[docIndex]['rating']!,
          );
        },
      ),
    );
  }

  Widget _buildDoctorWideCard({required String name, required String specialty, required String rating}) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left side: Full details
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(specialty, style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 12),
                          const SizedBox(width: 4),
                          Text(rating, style: GoogleFonts.inter(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                          minimumSize: const Size(0, 32),
                        ),
                        child: Text('Book Now', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right side: Doctor Photo
          Expanded(
            flex: 4,
            child: Container(
              height: double.infinity,
              decoration: BoxDecoration(
                color: backgroundBeige,
                borderRadius: BorderRadius.circular(16),
                image: const DecorationImage(
                  image: AssetImage('assetes/gm_logoo.png'), // Replace with actual doctor photo
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        children: [
          _buildQuickActionItem(LucideIcons.calendar, 'Book Appt', primaryGreen),
          const SizedBox(width: 16),
          _buildQuickActionItem(Icons.medical_services_outlined, 'Doctors', Colors.teal),
          const SizedBox(width: 16),
          _buildQuickActionItem(LucideIcons.activity, 'Pharmacy', Colors.orange),
          const SizedBox(width: 16),
          _buildQuickActionItem(Icons.emergency_outlined, 'Ambulance', Colors.red),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(IconData icon, String title, Color color) {
    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointmentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: backgroundBeige,
                  borderRadius: BorderRadius.circular(16),
                  image: const DecorationImage(
                    image: AssetImage('assetes/gm_logoo.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. Sarah Williams',
                      style: GoogleFonts.inter(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cardiologist - GM Hospital',
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundBeige,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, color: primaryGreen, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Mon, 27 Jun',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                ),
                const Spacer(),
                const Icon(LucideIcons.clock, color: primaryGreen, size: 18),
                const SizedBox(width: 8),
                Text(
                  '10:00 AM',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartments() {
    final departments = ['Cardiology', 'Neurology', 'Pediatrics', 'Orthopedics', 'Dentistry'];
    
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: departments.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              departments[index],
              style: GoogleFonts.inter(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 11),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        elevation: 0,
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(LucideIcons.home), activeIcon: Icon(LucideIcons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.calendar), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.messageSquare), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: 'Profile'),
        ],
      ),
    );
  }
}
