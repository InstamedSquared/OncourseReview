import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'face_recognition_screen.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  // Theme color (Light Blue)
  final Color _primaryColor = const Color(0xFF89D3EE);

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('saved_username');
    final savedPassword = prefs.getString('saved_password');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (rememberMe && savedUsername != null && savedPassword != null) {
      setState(() {
        _usernameController.text = savedUsername;
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Save credentials if Remember Me is checked
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_username', _usernameController.text);
      await prefs.setString('saved_password', _passwordController.text);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_username');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }

    final result = await ApiService.login(
      _usernameController.text,
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (mounted) {
        if (_usernameController.text.toLowerCase() == 'student') {
          // Bypass face recognition for the Apple App Store Reviewer
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainShell()));
        } else {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const FaceRecognitionScreen()));
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Login failed'),
            backgroundColor: _primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine current system brightness for text adaptation, but strictly keep background white if light theme requested
    // The user requested white background specifically, so we'll enforce the white/clean look.
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 50),
                
                // Temporary Placeholder for the requested red squiggle logo
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 130,
                        height: 130,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFFFFF),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ONCOURSE',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review & Development Center',
                        style: TextStyle(
                          fontSize: 18,
                          color: subtitleColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 50),
                
                // Username Field
                TextField(
                  controller: _usernameController,
                  style: TextStyle(color: subtitleColor, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(
                      color: subtitleColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: 'example@gmail.com',
                    hintStyle: TextStyle(color: subtitleColor.withOpacity(0.5)),
                    suffixIcon: Icon(Icons.person_outline, color: textColor, size: 20),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: subtitleColor.withOpacity(0.3), width: 1.5),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: _primaryColor, width: 2.0),
                    ),
                    contentPadding: const EdgeInsets.only(bottom: 8),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: subtitleColor, fontSize: 16, letterSpacing: _obscurePassword ? 4.0 : 0.0),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(
                      color: subtitleColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: ' ',
                    hintStyle: TextStyle(color: subtitleColor.withOpacity(0.5), letterSpacing: 4.0),
                    // Adding a combination of the requested Key icon and the Eye toggle
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: textColor.withOpacity(0.5),
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        Icon(Icons.vpn_key_outlined, color: textColor, size: 20),
                        const SizedBox(width: 8),
                      ],
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: subtitleColor.withOpacity(0.3), width: 1.5),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: _primaryColor, width: 2.0),
                    ),
                    contentPadding: const EdgeInsets.only(bottom: 8),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Remember Me Checkbox
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: _primaryColor,
                        checkColor: Colors.white,
                        side: BorderSide(color: subtitleColor),
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Remember me',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4.0), // Very slight rounding like mockup
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
