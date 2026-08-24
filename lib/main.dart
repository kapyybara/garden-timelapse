import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'ui/app_theme.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await bootstrap();

  runApp(const ProviderScope(child: GardenTimelapseApp()));
}

class GardenTimelapseApp extends ConsumerStatefulWidget {
  const GardenTimelapseApp({super.key});

  @override
  ConsumerState<GardenTimelapseApp> createState() => _GardenTimelapseAppState();
}

class _GardenTimelapseAppState extends ConsumerState<GardenTimelapseApp> {
  @override
  void initState() {
    super.initState();
    // Load the saved schedule once the tree is ready.
    Future.microtask(() =>
        ref.read(scheduleControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Garden Timelapse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeShell(),
    );
  }
}
