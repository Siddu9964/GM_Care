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
  
  final List<Map<String, dynamic>> _bulletins = [
    {
      'tag': 'ROBOTIC SURGERY',
      'title': '4th Gen Robotic Joint Suite',
      'subtitle': 'Sub-millimeter precision knee & hip replacement',
      'icon': Icons.precision_manufacturing_rounded,
      'badge': 'OPERATIONAL',
    },
    {
      'tag': 'CARDIAC EXCELLENCE',
      'title': '24/7 Primary Cath Lab',
      'subtitle': 'Door-to-balloon < 45m emergency angioplasty team',
      'icon': Icons.monitor_heart_rounded,
      'badge': 'CODE STEMI',
    },
    {
      'tag': 'DIAGNOSTIC RADIOLOGY',
      'title': '3T Digital MRI & PET-CT',
      'subtitle': 'AI-assisted ultra-fast diagnostic scans with PACS',
      'icon': Icons.biotech_rounded,
      'badge': 'SAME DAY REPORT',
    },
    {
      'tag': 'LEVEL-1 TRAUMA',
      'title': 'Rapid Stroke Resuscitation',
      'subtitle': 'Comprehensive stroke unit with neuro-intervention',
      'icon': Icons.medical_services_rounded,
      'badge': 'NABH ACCREDITED',
    },
    {
      'tag': 'SUPER SPECIALTY',
      'title': 'Organ Transplant Institute',
      'subtitle': 'Multi-disciplinary liver, renal & cornea transplant',
      'icon': Icons.healing_rounded,
      'badge': 'CENTRE OF EXCELLENCE',
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
        double delta = 1.2;
        
        if (currentScroll >= maxScroll - 40) {
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Hospital Bulletin",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF143B2A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Centers of Excellence & Technology",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5A6E64),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F6B4A).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1F6B4A).withOpacity(0.2)),
                ),
                child: const Text(
                  "NABH CERTIFIED",
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF1F6B4A)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 118,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final item = _bulletins[index % _bulletins.length];
              return Container(
                width: 290,
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF143B2A), Color(0xFF1F6B4A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF26875B).withOpacity(0.4), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF143B2A).withOpacity(0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item['tag'] as String,
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFF3EFE6),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF26875B),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item['badge'] as String,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item['icon'] as IconData, color: const Color(0xFFF3EFE6), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item['title'] as String,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['subtitle'] as String,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFF3EFE6).withOpacity(0.85),
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
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
