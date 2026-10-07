import 'package:flutter/material.dart';
import 'package:mood_bunny/bunny/bunny_host.dart';
import 'package:mood_bunny/bunny/bunny_screen.dart';
import 'package:mood_bunny/bunny/desktop_pet.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Same exe, two modes: `--pet` runs the transparent desktop pet
  // (tray + autostart, shows even when the main app is closed).
  if (isPetMode(args)) {
    await runDesktopPet();
    return;
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mood Bunny',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      // BunnyHost via builder so EVERY route is a descendant.
      // Pure Flutter overlay, no desktop plugin needed for this part.
      builder: (ctx, child) => BunnyHost(child: child!),
      home: const BunnyScreen(),
    );
  }
}
