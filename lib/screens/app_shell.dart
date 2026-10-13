import 'package:flutter/material.dart';

import '../widgets/app_colors.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'photo_input_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  Future<void> _openCamera() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PhotoInputScreen()));
    if (mounted) setState(() {});
  }

  void _selectTab(int index) => setState(() => _selectedIndex = index);

  Future<void> _openProfile() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onCapture: _openCamera,
        onOpenHistory: () => _selectTab(1),
        onOpenInsights: () => _selectTab(2),
        onOpenProfile: _openProfile,
      ),
      const HistoryScreen(embedded: true),
      const InsightsScreen(),
      ShopScreen(onOpenProfile: _openProfile),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          border: Border.all(color: Colors.white, width: 6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4512B9A1),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: IconButton(
          tooltip: '식사 촬영',
          onPressed: _openCamera,
          icon: const Icon(
            Icons.camera_alt_rounded,
            color: Colors.white,
            size: 29,
          ),
        ),
      ),
      bottomNavigationBar: _AppBottomBar(
        selectedIndex: _selectedIndex,
        onSelected: _selectTab,
      ),
    );
  }
}

class _AppBottomBar extends StatelessWidget {
  const _AppBottomBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: 18,
      shadowColor: const Color(0x33132639),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.home_rounded,
              label: '홈',
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.receipt_long_rounded,
              label: '기록',
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
          ),
          const SizedBox(width: 72),
          Expanded(
            child: _NavItem(
              icon: Icons.bar_chart_rounded,
              label: '가이드',
              selected: selectedIndex == 2,
              onTap: () => onSelected(2),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.shopping_bag_outlined,
              label: '쇼핑',
              selected: selectedIndex == 3,
              onTap: () => onSelected(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryDark : AppColors.muted;
    return InkResponse(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 23, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
