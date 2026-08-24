import 'package:flutter/material.dart';

import 'camera_screen.dart';
import 'export_screen.dart';
import 'gallery_screen.dart';
import 'reminders_screen.dart';

/// Root shell: bottom navigation between Camera, Gallery, Reminders, Export.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    CameraScreen(),
    GalleryScreen(),
    RemindersScreen(),
    ExportScreen(),
  ];

  static const _icons = [
    Icons.photo_camera_outlined,
    Icons.calendar_month_outlined,
    Icons.notifications_active_outlined,
    Icons.video_library_outlined,
  ];
  static const _labels = ['Camera', 'Gallery', 'Reminders', 'Export'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (var i = 0; i < _tabs.length; i++)
            NavigationDestination(
              icon: Icon(_icons[i]),
              label: _labels[i],
            ),
        ],
      ),
    );
  }
}
