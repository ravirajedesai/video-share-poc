import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize available cameras
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Failed to load cameras: $e');
  }

  // Initialize Firebase with generated platform options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Sign in anonymously for PoC if not already logged in
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e) {
    debugPrint('Firebase initialization note: $e');
  }

  // Initialize Supabase Storage
  try {
    await Supabase.initialize(
      url: 'https://fayyujfeqsmiohegdzuk.supabase.co',
      publishableKey: 'sb_publishable_yjS_RNeKNMFWjRYeeYghrw_wT-PEtDC',
    );
  } catch (e) {
    debugPrint('Supabase initialization note: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Share PoC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: HomeScreen(cameras: cameras),
    );
  }
}
