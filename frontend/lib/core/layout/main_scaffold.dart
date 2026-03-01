import 'package:flutter/material.dart';
import '../widgets/common/app_bottom_nav.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/schedule/schedule_screen.dart';
import '../../screens/task/task_screen.dart';
import '../../screens/profile/profile_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();

  /// Navigate to a specific tab by index
  static void navigateToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainScaffoldState>();
    state?.switchToTab(index);
  }
}

class _MainScaffoldState extends State<MainScaffold> {
  int _screenIndex = 0;

  void switchToTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() {
        _screenIndex = index;
      });
    }
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    ScheduleScreen(),
    TaskScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _screenIndex,
        children: _screens,
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _screenIndex,
        onTap: (index) {
          setState(() {
            _screenIndex = index;
          });
        },
      ),
    );
  }
}