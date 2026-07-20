import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'notifications_screen.dart';
import '../config/api_config.dart';
import '../widgets/appointments_section.dart';
import '../widgets/auto_scroll_offers.dart';
import '../widgets/radial_quick_services_hub.dart';
import '../widgets/app_bottom_nav_bar.dart';
import 'account_screen.dart';
import 'appointments_screen.dart';
import 'billing_history_screen.dart';
import 'health_reports_screen.dart';
import 'specialist_doctors_screen.dart';

class PatientDashboard extends StatefulWidget {
  final String userName;
  final String location;
  final String age;
  final String sex;
  final String cookie;

  const PatientDashboard({
    super.key, 
    this.userName = "Jane", 
    this.location = "New York, NY",
    this.age = "--",
    this.sex = "Unknown",
    this.cookie = "",
  });

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  String get userName => widget.userName;
  String get location => widget.location;
  String get age => widget.age;
  String get sex => widget.sex;
  String get cookie => widget.cookie;

  Key _refreshKey = UniqueKey();
  int _activeNavIndex = 0;
  List<dynamic> _doctors = [];
  bool _isLoadingDoctors = true;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Heart', 'Brain', 'Dental', 'Child Care', 'ENT', 'Eye', 'Skin', 'Orthopedic', 'Women Care'];
  String? _profileImageUrl;

  // Cover Flow State
  late PageController _pageController;
  int _currentSpecialtyPage = 10000; 
  bool _autoPlayCarousel = true;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
    _fetchPatientProfile();
    _pageController = PageController(viewportFraction: 0.82, initialPage: _currentSpecialtyPage);
    _startCarouselTimer();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    if (_autoPlayCarousel) {
      _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (_pageController.hasClients) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }
  }

  void _toggleAutoPlay() {
    setState(() {
      _autoPlayCarousel = !_autoPlayCarousel;
    });
    if (_autoPlayCarousel) {
      _startCarouselTimer();
    } else {
      _carouselTimer?.cancel();
    }
  }

  Future<void> _fetchPatientProfile() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.patientSearch(widget.userName)),
        headers: {
          'X-Hospital-Branch': widget.location,
          'Accept': 'application/json',
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final patientsList = json['data']?['data'] ?? [];
        if (patientsList.isNotEmpty && mounted) {
          setState(() {
            _profileImageUrl = patientsList[0]['image'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    }
  }

  Future<void> _fetchDoctors() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.doctors),
        headers: {
          'X-Hospital-Branch': widget.location,
          'Accept': 'application/json',
          if (widget.cookie.isNotEmpty) 'Cookie': widget.cookie,
        },
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['data'] != null && mounted) {
          setState(() {
            _doctors = json['data'];
            _isLoadingDoctors = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching doctors: $e');
    }
    if (mounted) {
      setState(() => _isLoadingDoctors = false);
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _refreshKey = UniqueKey();
    });
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFE6),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                key: _refreshKey,
                padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 110.0),
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const Divider(color: Color(0xFF1F6B4A), thickness: 1, height: 32),
                    _buildFindDoctorsBySpeciality(),
                    const SizedBox(height: 24),
                    AppointmentsSection(location: location, cookie: cookie, userName: userName),
                    const SizedBox(height: 16),
                    RadialQuickServicesHub(userName: userName, location: location, cookie: cookie, age: age, sex: sex),
                    const SizedBox(height: 16),
                    const AutoScrollOffers(),
                    const SizedBox(height: 16),
                    _buildHealthInsights(),
                  ],
                ),
              ),
            ),
            // Premium floating bottom nav
            AppBottomNavBar(
              currentIndex: _activeNavIndex,
              onTap: (idx) {
                setState(() => _activeNavIndex = idx);
                if (idx == 1) {
                  Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => AppointmentsScreen(
                      cookie: widget.cookie,
                      location: widget.location,
                      userName: widget.userName,
                      age: widget.age,
                      sex: widget.sex,
                    )));
                } else if (idx == 3) {
                  Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => AccountScreen(
                      userName: widget.userName,
                      location: widget.location,
                      cookie: widget.cookie,
                      age: widget.age,
                      sex: widget.sex,
                    )));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    ImageProvider avatarImage;
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      if (_profileImageUrl!.startsWith('data:image')) {
        final base64String = _profileImageUrl!.split(',').last;
        avatarImage = MemoryImage(base64Decode(base64String));
      } else if (_profileImageUrl!.startsWith('http')) {
        avatarImage = NetworkImage(_profileImageUrl!);
      } else if (_profileImageUrl!.length > 100 && !_profileImageUrl!.startsWith('/')) {
        avatarImage = MemoryImage(base64Decode(_profileImageUrl!));
      } else {
        avatarImage = NetworkImage('${ApiConfig.imageBaseUrl}$_profileImageUrl');
      }
    } else {
      avatarImage = const NetworkImage('https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150');
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              backgroundImage: avatarImage,
            ),
            const SizedBox(width: 12),
            Text(
              "Welcome back, $userName",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F6B4A)),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NotificationsScreen(patientId: widget.userName),
              ),
            );
          },
          child: const Icon(Icons.notifications_none_outlined, size: 24, color: Color(0xFF1F6B4A)),
        ),
      ],
    );
  }

  Widget _buildServiceCard(String title, IconData icon, Color bgColor, Color iconColor, VoidCallback onTap) {
    return Column(
      children: [
        Container(          height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.2), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1F6B4A).withOpacity(0.12),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              highlightColor: bgColor,
              splashColor: bgColor.withOpacity(0.3),
              child: Center(
                child: Icon(icon, size: 24, color: iconColor),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1F6B4A), height: 1.2),
        ),
      ],
    );
  }

  String _getSpecialtyImagePath(String spec) {
    final s = spec.trim().toLowerCase();
    if (s.contains('cardio') || s.contains('heart')) return 'assetes/Department/Cardiology.jpg';
    if (s.contains('neuro') || s.contains('brain')) return 'assetes/Department/Neurology.jpg';
    if (s.contains('ortho') || s.contains('bone')) return 'assetes/Department/Orthopedics.jpg';
    if (s.contains('pediatric') || s.contains('paediatric') || s.contains('child')) return 'assetes/Department/PAEDIATRICIAN.jpg';
    if (s.contains('derma') || s.contains('skin')) return 'assetes/Department/Dermatology.jpg';
    if (s.contains('gynec') || s.contains('women') || s.contains('obste')) return 'assetes/Department/GYNECOLOGIST.jpg';
    if (s.contains('gastro')) return 'assetes/Department/GASTRO SURGEON.jpg';
    if (s.contains('ent')) return 'assetes/Department/ENT.jpg';
    if (s.contains('nephro')) return 'assetes/Department/NEPHROLOGIST.jpg';
    if (s.contains('physio')) return 'assetes/Department/PHYSIO.jpg';
    if (s.contains('plastic')) return 'assetes/Department/PLASTIC SURGEON.jpg';
    if (s.contains('psychiat')) return 'assetes/Department/PSYCHIATRIST.jpg';
    if (s.contains('pulmono')) return 'assetes/Department/PULMONOLOGIST.jpg';
    if (s.contains('radio')) return 'assetes/Department/RADIOLOGIST.jpg';
    if (s.contains('urolo')) return 'assetes/Department/UROLOGIST.jpg';
    if (s.contains('onco')) return 'assetes/Department/SURGICAL ONCOLOGIST.jpg';
    if (s.contains('anesth')) return 'assetes/Department/ANESTHESIOLOGIST.jpg';
    if (s.contains('microbio')) return 'assetes/Department/MICROBIOLOGIST.jpg';
    if (s.contains('general surg') || s.contains('surge')) return 'assetes/Department/GENERAL SURGEON.jpg';
    return 'assetes/Department/General Medicine.jpg';
  }

  String _getSpecialtyDesc(String spec) {
    final s = spec.toLowerCase();
    if (s.contains('cardio') || s.contains('heart')) return 'Expert care for heart health and treatment';
    if (s.contains('neuro') || s.contains('brain')) return 'Advanced care for brain and nervous system';
    if (s.contains('pediatric') || s.contains('child')) return 'Special care for children''s health';
    if (s.contains('dent') || s.contains('tooth')) return 'Complete oral health solutions';
    if (s.contains('derma') || s.contains('skin')) return 'Skin, hair & nail care solutions';
    if (s.contains('ortho') || s.contains('bone')) return 'Bone, joint & muscle care and treatment';
    if (s.contains('eye') || s.contains('opthal')) return 'Comprehensive vision & eye care';
    if (s.contains('gynec') || s.contains('women')) return 'Expert women''s health & maternity care';
    return 'Comprehensive health diagnosis and treatment';
  }

  Widget _buildFindDoctorsBySpeciality() {
    List<String> specialities = [];
    Map<String, int> doctorCounts = {};
    
    if (_doctors.isNotEmpty) {
      final uniqueSpecs = _doctors
          .map((d) => d['specialization']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      uniqueSpecs.sort();
      specialities.addAll(uniqueSpecs);

      for (final spec in specialities) {
        doctorCounts[spec] = _doctors
            .where((d) => (d['specialization']?.toString() ?? '').trim().toLowerCase() == spec.trim().toLowerCase())
            .length;
      }
    }

    if (_selectedCategory != 'All') {
      final cat = _selectedCategory.toLowerCase();
      specialities = specialities.where((spec) {
        final s = spec.toLowerCase();
        if (cat.contains('heart')) return s.contains('cardio') || s.contains('heart');
        if (cat.contains('brain')) return s.contains('neuro') || s.contains('brain');
        if (cat.contains('dental')) return s.contains('dent') || s.contains('tooth');
        if (cat.contains('child')) return s.contains('pediatric') || s.contains('paediatric') || s.contains('child');
        if (cat.contains('women')) return s.contains('gynec') || s.contains('women') || s.contains('obste');
        if (cat.contains('bone') || cat.contains('ortho')) return s.contains('ortho') || s.contains('bone');
        if (cat.contains('skin')) return s.contains('derma') || s.contains('skin');
        if (cat.contains('ent')) return s.contains('ent');
        if (cat.contains('eye')) return s.contains('eye') || s.contains('opthal');
        return false;
      }).toList();
    }

    final navContext = context;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // -- Section Header ----------------------------------------
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Specialties',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F6B4A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Expert care for your health',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1F6B4A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // -- Filter Chips -----------------------------------------
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                    _currentSpecialtyPage = 10000;
                    if (_pageController.hasClients) {
                      _pageController.jumpToPage(_currentSpecialtyPage);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: index == _categories.length - 1 ? 0 : 10),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1F6B4A) : const Color(0xFFF3EFE6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF1F6B4A) : const Color(0xFF1F6B4A).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (cat == 'All') ...[
                        Icon(Icons.grid_view_rounded, size: 16, color: isSelected ? Colors.white : const Color(0xFF1F6B4A)),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF1F6B4A),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // -- Explore Specialties Responsive Area ---------------------------------
        _isLoadingDoctors
            ? _buildSpecialityShimmer()
            : specialities.isEmpty
                ? _buildEmptySpeciality()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final bool isMobile = width < 600;
                      final bool isTablet = width >= 600 && width <= 1024;
                      final bool isDesktop = width > 1024;

                      if (isMobile && _pageController.viewportFraction != 0.75) {
                        final oldPage = _pageController.hasClients ? _pageController.page?.round() ?? _currentSpecialtyPage : _currentSpecialtyPage;
                        _pageController.dispose();
                        _pageController = PageController(viewportFraction: 0.75, initialPage: oldPage);
                      } else if (isTablet && _pageController.viewportFraction != 0.50) {
                        final oldPage = _pageController.hasClients ? _pageController.page?.round() ?? _currentSpecialtyPage : _currentSpecialtyPage;
                        _pageController.dispose();
                        _pageController = PageController(viewportFraction: 0.50, initialPage: oldPage);
                      }

                      Widget content;

                      if (isDesktop) {
                        content = Wrap(
                          spacing: 24,
                          runSpacing: 24,
                          alignment: WrapAlignment.center,
                          children: specialities.map((spec) {
                            final docCount = doctorCounts[spec] ?? 0;
                            final imagePath = _getSpecialtyImagePath(spec);
                            final desc = _getSpecialtyDesc(spec);
                            final filteredDocs = _doctors
                                .where((d) => (d['specialization']?.toString() ?? '').trim().toLowerCase() == spec.trim().toLowerCase())
                                .toList();

                            return SizedBox(
                              width: 320,
                              height: 380,
                              child: CoverFlowSpecialtyCard(
                                spec: spec,
                                imagePath: imagePath,
                                desc: desc,
                                doctorCount: docCount,
                                isActive: true,
                                isDesktop: true,
                                onTap: () {
                                  Navigator.push(navContext, MaterialPageRoute(builder: (_) => SpecialistDoctorsScreen(
                                    specialization: spec, doctors: filteredDocs, userName: widget.userName, location: widget.location, age: widget.age, sex: widget.sex, cookie: widget.cookie,
                                  )));
                                },
                              ),
                            );
                          }).toList(),
                        );
                      } else {
                        content = Column(
                          children: [
                            SizedBox(
                              height: 380,
                              child: PageView.builder(
                                controller: _pageController,
                                physics: const BouncingScrollPhysics(),
                                onPageChanged: (idx) {
                                  setState(() => _currentSpecialtyPage = idx);
                                },
                                itemBuilder: (context, index) {
                                  final specIndex = index % specialities.length;
                                  final spec = specialities[specIndex];
                                  final docCount = doctorCounts[spec] ?? 0;
                                  final imagePath = _getSpecialtyImagePath(spec);
                                  final desc = _getSpecialtyDesc(spec);

                                  final filteredDocs = _doctors
                                      .where((d) => (d['specialization']?.toString() ?? '').trim().toLowerCase() == spec.trim().toLowerCase())
                                      .toList();

                                  return AnimatedBuilder(
                                    animation: _pageController,
                                    builder: (context, child) {
                                      double diff = 0.0;
                                      if (_pageController.position.haveDimensions) {
                                        diff = _pageController.page! - index;
                                      } else {
                                        diff = (_currentSpecialtyPage - index).toDouble();
                                      }
                                      
                                      final double scale = (1 - (diff.abs() * 0.15)).clamp(0.85, 1.0);
                                      final double opacity = (1 - (diff.abs() * 0.40)).clamp(0.60, 1.0);

                                      return Transform.scale(
                                        scale: scale,
                                        child: Opacity(
                                          opacity: opacity,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: CoverFlowSpecialtyCard(
                                      spec: spec,
                                      imagePath: imagePath,
                                      desc: desc,
                                      doctorCount: docCount,
                                      isActive: index == _currentSpecialtyPage,
                                      isDesktop: false,
                                      onTap: () {
                                        if (index != _currentSpecialtyPage) {
                                          _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOutCubic);
                                        } else {
                                          Navigator.push(navContext, MaterialPageRoute(builder: (_) => SpecialistDoctorsScreen(
                                            specialization: spec, doctors: filteredDocs, userName: widget.userName, location: widget.location, age: widget.age, sex: widget.sex, cookie: widget.cookie,
                                          )));
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (specialities.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  specialities.length > 5 ? 5 : specialities.length, 
                                  (idx) {
                                    final activeIdx = _currentSpecialtyPage % specialities.length;
                                    final isDotActive = activeIdx == idx || (activeIdx >= 5 && idx == 4);
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOutCubic,
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      height: 6,
                                      width: isDotActive ? 24 : 8,
                                      decoration: BoxDecoration(
                                        color: isDotActive ? const Color(0xFF1F6B4A) : const Color(0xFF1F6B4A).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        );
                      }

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeInOutCubic,
                        switchOutCurve: Curves.easeInOutCubic,
                        child: content,
                      );
                    },
                  ),
      ],
    );
  }

  Widget _buildSpecialityShimmer() {
    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.05)),
      ),
      child: const Center(child: CircularProgressIndicator(color: Color(0xFF1F6B4A))),
    );
  }

  Widget _buildEmptySpeciality() {
    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1F6B4A).withOpacity(0.06),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.15)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, color: Color(0xFF1F6B4A), size: 36),
          SizedBox(height: 10),
          Text('No specializations found.',
              style: TextStyle(color: Color(0xFF1F6B4A), fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }


  final List<Map<String, dynamic>> _insights = [
    {
      'title': 'Healthy Habits for a Better Life',
      'category': 'Wellness',
      'readTime': '5 min read',
      'icon': Icons.spa_rounded,
      'color': const Color(0xFF4A90E2),
      'summary': 'Discover simple daily habits that can significantly improve your overall physical and mental well-being.',
      'sections': [
        {'heading': 'Stay Hydrated', 'body': 'Drinking enough water every day is crucial for many reasons: to regulate body temperature, keep joints lubricated, prevent infections, deliver nutrients to cells, and keep organs functioning properly.'},
        {'heading': 'Get Enough Sleep', 'body': 'Sleep is an essential function that allows your body and mind to recharge, leaving you refreshed and alert when you wake up.'}
      ],
    },
    {
      'title': 'Heart Health: What You Need to Know',
      'category': 'Cardiology',
      'readTime': '4 min read',
      'icon': Icons.favorite_rounded,
      'color': const Color(0xFFE24A4A),
      'summary': 'Learn how to protect your heart through diet, exercise, and stress management.',
      'sections': [
        {'heading': 'Eat a Heart-Healthy Diet', 'body': 'Focus on fruits, vegetables, whole grains, and lean proteins. Limit saturated fats, sodium, and added sugars.'},
        {'heading': 'Stay Active', 'body': 'Aim for at least 150 minutes of moderate aerobic exercise or 75 minutes of vigorous exercise each week.'}
      ],
    },
    {
      'title': 'The Importance of Mental Health',
      'category': 'Mental Health',
      'readTime': '6 min read',
      'icon': Icons.psychology_rounded,
      'color': const Color(0xFF904AE2),
      'summary': 'Understanding the crucial link between mental well-being and physical health.',
      'sections': [
        {'heading': 'Manage Stress', 'body': 'Chronic stress can lead to numerous physical problems. Practice relaxation techniques like meditation, yoga, or deep breathing.'},
        {'heading': 'Seek Support', 'body': 'Don\'t hesitate to reach out to friends, family, or professionals if you are feeling overwhelmed.'}
      ],
    },
    {
      'title': 'Nutrition Myths Debunked',
      'category': 'Diet',
      'readTime': '3 min read',
      'icon': Icons.restaurant_rounded,
      'color': const Color(0xFFE2904A),
      'summary': 'We clarify some of the most common misconceptions about food and dieting.',
      'sections': [
        {'heading': 'Carbs Are Not the Enemy', 'body': 'Complex carbohydrates are essential for energy. Focus on whole grains and avoid refined sugars.'},
        {'heading': 'Eating Late Doesn\'t Guarantee Weight Gain', 'body': 'It\'s total caloric intake that matters most, though eating heavy meals late can disrupt sleep.'}
      ],
    },
    {
      'title': 'Benefits of Daily Stretching',
      'category': 'Fitness',
      'readTime': '2 min read',
      'icon': Icons.accessibility_new_rounded,
      'color': const Color(0xFF4AE290),
      'summary': 'Why taking 5 minutes a day to stretch can transform your mobility and reduce pain.',
      'sections': [
        {'heading': 'Improved Flexibility', 'body': 'Regular stretching helps maintain the range of motion in your joints, preventing injuries.'},
        {'heading': 'Better Posture', 'body': 'Stretching the muscles of the lower back, shoulders, and chest can help keep your back in better alignment.'}
      ],
    },
  ];

  Widget _buildHealthInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Health Insights", 
            style: TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.w900, 
              color: Color(0xFF1F6B4A),
              letterSpacing: -0.5,
            )
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Curated articles for your wellness", 
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w500, 
              color: Color(0xFF1F6B4A),
            )
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _insights.length,
            itemBuilder: (context, index) {
              final insight = _insights[index];
              final color = insight['color'] as Color;
              return GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => _ArticleReaderSheet(
                      article: insight,
                      catColor: color,
                    ),
                  );
                },
                child: Container(
                  width: 260,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Icon(
                            insight['icon'] as IconData,
                            size: 100,
                            color: color.withOpacity(0.05),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      insight['category'] as String,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    insight['readTime'] as String,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                insight['title'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFF1A1A2E),
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                insight['summary'] as String,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class CoverFlowSpecialtyCard extends StatelessWidget {
  final String spec;
  final String imagePath;
  final String desc;
  final int doctorCount;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDesktop;

  const CoverFlowSpecialtyCard({
    super.key,
    required this.spec,
    required this.imagePath,
    required this.desc,
    required this.doctorCount,
    required this.isActive,
    required this.onTap,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        margin: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 4, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F6B4A).withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3EFE6),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.medical_services, size: 60, color: Color(0xFF1F6B4A))),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Text(
                            "100% Match",
                            style: TextStyle(
                              color: Color(0xFF1F6B4A),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            spec,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2D3748),
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            desc,
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF2D3748).withOpacity(0.7),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2904A),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE2904A).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          "Find Doctors",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _ArticleReaderSheet extends StatelessWidget {
  final Map<String, dynamic> article;
  final Color catColor;

  const _ArticleReaderSheet({super.key, required this.article, required this.catColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            width: 48,
            height: 6,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              children: [
                if (article['imageUrl'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(article['imageUrl'], height: 200, width: double.infinity, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 20),
                Text(article['title'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(article['category'] ?? '', style: TextStyle(color: catColor, fontSize: 13, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 12),
                    Text(article['readTime'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 20),
                Text(article['summary'] ?? '', style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600, height: 1.5)),
                const SizedBox(height: 24),
                if (article['sections'] != null)
                  ...(article['sections'] as List).map((sec) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sec['heading'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F6B4A))),
                        const SizedBox(height: 10),
                        Text(sec['body'] ?? '', style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6)),
                      ],
                    ),
                  )).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}