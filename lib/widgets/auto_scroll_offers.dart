import 'dart:async';
import 'package:flutter/material.dart';

class AutoScrollOffers extends StatefulWidget {
  const AutoScrollOffers({Key? key}) : super(key: key);

  @override
  State<AutoScrollOffers> createState() => _AutoScrollOffersState();
}

class _AutoScrollOffersState extends State<AutoScrollOffers> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  
  final List<Map<String, dynamic>> _offers = [
    {
      'title': 'Free Health Checkup',
      'subtitle': 'For senior citizens every Sunday',
      'icon': Icons.favorite_rounded,
      'color': Colors.red,
    },
    {
      'title': '20% Off Lab Tests',
      'subtitle': 'Use code HEALTH20 today',
      'icon': Icons.science_rounded,
      'color': Colors.blue,
    },
    {
      'title': '24/7 Emergency',
      'subtitle': 'World-class trauma center ready',
      'icon': Icons.emergency_rounded,
      'color': Colors.orange,
    },
    {
      'title': 'Advanced ICU',
      'subtitle': 'Equipped with modern technology',
      'icon': Icons.local_hospital_rounded,
      'color': Colors.purple,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.position.pixels;
        double delta = 1.5; // Scroll speed
        
        if (currentScroll >= maxScroll - 50) {
          // If we reach near the end, jump back to start smoothly (since it's an infinite loop)
          _scrollController.jumpTo(0);
        } else {
          _scrollController.animateTo(
            currentScroll + delta,
            duration: const Duration(milliseconds: 50),
            curve: Curves.linear,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Hospital Updates & Offers", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F6B4A))),
        const SizedBox(height: 16),
        SizedBox(
          height: 110,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              // Infinite loop
              final item = _offers[index % _offers.length];
              return Container(
                width: 250,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F6B4A), // Dark green background
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF1F6B4A).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(item['icon'] as IconData, color: const Color(0xFFF3EFE6), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item['title'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFF3EFE6))),
                          const SizedBox(height: 4),
                          Text(item['subtitle'] as String, style: TextStyle(fontSize: 11, color: const Color(0xFFF3EFE6).withOpacity(0.8))),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
