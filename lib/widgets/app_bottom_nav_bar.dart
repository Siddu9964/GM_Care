import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────
//  App-wide Premium Bottom Navigation Bar
//  Usage:
//    AppBottomNavBar(currentIndex: 0, onTap: (i) { ... })
//
//  Indices:  0 = Home | 1 = Appointments | 2 = Chat | 3 = Profile
// ─────────────────────────────────────────────────────────────

const _kGreen     = Color(0xFF1F6B4A);
const _kGreenGlow = Color(0xFF26875B);

class AppBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ripple;

  @override
  void initState() {
    super.initState();
    _ripple = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  static const _items = [
    _NavItem(Icons.local_hospital_rounded, Icons.local_hospital_outlined, 'Hospital'),
    _NavItem(Icons.calendar_today_rounded, Icons.calendar_today_outlined, 'OPD Visits'),
    _NavItem(Icons.support_agent_rounded, Icons.support_agent_outlined, '24x7 Desk'),
    _NavItem(Icons.badge_rounded, Icons.badge_outlined, 'Medical ID'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final screenW = MediaQuery.of(context).size.width;
    final isTablet = screenW > 600;
    final navWidth = isTablet ? 520.0 : screenW - 28.0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPad > 0 ? bottomPad + 6 : 14, left: 14, right: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              width: navWidth,
              height: 66,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: const Color(0xFF1F6B4A).withOpacity(0.12),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF143B2A).withOpacity(0.10),
                    blurRadius: 28,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: const Color(0xFF1F6B4A).withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_items.length, (i) {
                  final item = _items[i];
                  final selected = widget.currentIndex == i;
                  return _NavButton(
                    item: item,
                    selected: selected,
                    ripple: _ripple,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onTap(i);
                    },
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Individual nav button
// ─────────────────────────────────────────────────────────────
class _NavButton extends StatefulWidget {
  final _NavItem item;
  final bool selected;
  final AnimationController ripple;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.ripple,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scale;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _scale, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _scale.forward();
  void _onTapUp(_)   { _scale.reverse(); widget.onTap(); }
  void _onTapCancel()=> _scale.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   _onTapDown,
      onTapUp:     _onTapUp,
      onTapCancel: _onTapCancel,
      behavior:    HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: SizedBox(
          width: 66,
          height: 64,
          child: widget.selected ? _SelectedItem(widget.item, widget.ripple)
                                 : _UnselectedItem(widget.item),
        ),
      ),
    );
  }
}

// ─── Selected state ───────────────────────────────────────────
class _SelectedItem extends StatelessWidget {
  final _NavItem item;
  final AnimationController ripple;
  const _SelectedItem(this.item, this.ripple);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: ripple,
          builder: (_, child) => Container(
            width: 46,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kGreen, _kGreenGlow],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _kGreen.withOpacity(0.28 + ripple.value * 0.15),
                  blurRadius: 10 + ripple.value * 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
          child: Icon(item.selectedIcon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 4),
        Text(
          item.label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: _kGreen,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ─── Unselected state ─────────────────────────────────────────
class _UnselectedItem extends StatelessWidget {
  final _NavItem item;
  const _UnselectedItem(this.item);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(item.icon, color: const Color(0xFFADB5BD), size: 22),
        ),
        const SizedBox(height: 4),
        Text(
          item.label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFFADB5BD),
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Data class
// ─────────────────────────────────────────────────────────────
class _NavItem {
  final IconData selectedIcon;
  final IconData icon;
  final String label;
  const _NavItem(this.selectedIcon, this.icon, this.label);
}
