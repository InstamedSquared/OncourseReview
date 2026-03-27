import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Decide initial route based on existing session
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final rememberMe = prefs.getBool('remember_me') ?? false;
  final faceVerified = prefs.getBool('face_verified') ?? false;
  
  Widget initialScreen = const LoginScreen();
  
  if (rememberMe && token != null && faceVerified) {
    // If the user checked "Remember me", has an active token, AND successfully verified their face
    initialScreen = const MainShell();
  } else {
    // If they killed the app before face recognition or didn't check remember me, wipe the active session
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('student_id');
    await prefs.remove('face_verified');
  }

  runApp(OncourseApp(initialScreen: initialScreen));
}

class OncourseApp extends StatelessWidget {
  final Widget initialScreen;
  const OncourseApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.light,
          seedColor: const Color(0xFF89D3EE),
          primary: const Color(0xFF89D3EE),
        ),
        appBarTheme: const AppBarTheme(
          color: Color(0xFF89D3EE),
          elevation: 0,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF89D3EE),
          primary: const Color(0xFF89D3EE),
        ),
        appBarTheme: const AppBarTheme(
          color: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      themeMode: ThemeMode.system,
      home: initialScreen,
      debugShowCheckedModeBanner: false,
    );
  }
}
