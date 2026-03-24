import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _errorMessage;

  final Color _themeColor = const Color(0xFF89D3EE);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('student_id');

    if (studentId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Not logged in';
      });
      return;
    }

    final result = await ApiService.getProfile(studentId);

    if (result['success'] == true) {
      setState(() {
        _profile = result['profile'];
        _isLoading = false;
      });
    } else {
      final userJson = prefs.getString('user');
      if (userJson != null) {
        setState(() {
          _profile = jsonDecode(userJson);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result['message'] ?? 'Failed to load profile';
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _themeColor));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(_errorMessage!, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProfile,
              style: ElevatedButton.styleFrom(backgroundColor: _themeColor, foregroundColor: Colors.black),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_profile == null) {
      return const Center(child: Text('No profile data'));
    }

    final fullName = '${_profile!['fn'] ?? ''} ${_profile!['mn'] ?? ''} ${_profile!['ln'] ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();
    final initials = '${(_profile!['fn'] ?? 'O')[0]}${(_profile!['ln'] ?? 'C')[0]}'.toUpperCase();
    final profileImageUrl = _profile!['profile_image'] ?? '';
    final email = _profile!['email'] ?? '';
    final phone = _profile!['phone'] ?? '';
    final address = _profile!['address'] ?? '';
    final className = _profile!['class_name'] ?? 'N/A';
    final levelName = _profile!['level_name'] ?? 'N/A';
    final kind = (_profile!['kind'] ?? 'student').toString().toUpperCase();

    return RefreshIndicator(
      color: _themeColor,
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // ── Top Header Section ───────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isDark ? _themeColor.withOpacity(0.15) : _themeColor.withOpacity(0.08),
                    isDark ? _themeColor.withOpacity(0.02) : _themeColor.withOpacity(0.02),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                   // Decorative blur elements in header
                   Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _themeColor.withOpacity(0.2),
                            Colors.transparent,
                          ]
                        )
                      ),
                    ),
                  ),

                  Column(
                    children: [
                      // Profile Photo
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _themeColor.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(color: _themeColor.withOpacity(0.3), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 53,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
                            child: profileImageUrl.isEmpty
                                ? Text(
                                    initials,
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: _themeColor,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name
                      Text(
                        fullName,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 0.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── About section ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _sectionHeader('Personal Information', subtitleColor),
                  const SizedBox(height: 10),
                  _infoCard([
                    _infoRow(Icons.email_outlined, 'Email', email.isNotEmpty ? email : 'N/A', textColor),
                    _divider(),
                    _infoRow(Icons.phone_outlined, 'Phone', phone.isNotEmpty ? phone : 'N/A', textColor),
                    _divider(),
                    _infoRow(Icons.location_on_outlined, 'Address', address.isNotEmpty ? address : 'N/A', textColor),
                  ], isDark),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ── Academic section ───────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _sectionHeader('Academic Information', subtitleColor),
                  const SizedBox(height: 10),
                  _infoCard([
                    _infoRow(Icons.class_outlined, 'Course', className, textColor),
                    _divider(),
                    _infoRow(Icons.layers_outlined, 'Level', levelName, textColor),
                  ], isDark),
                ],
              ),
            ),

            const SizedBox(height: 32),
            
            // ── Logout Button ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: InkWell(
                onTap: _handleLogout,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.shade400.withOpacity(0.8),
                        Colors.red.shade600,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'LOGOUT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48), // Extra space at bottom
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _infoCard(List<Widget> children, bool isDark) {
    final baseBgColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final shadowColor = isDark ? Colors.black.withOpacity(0.8) : _themeColor.withOpacity(0.15);
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : _themeColor.withOpacity(0.1);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? _themeColor.withOpacity(0.1) : _themeColor.withOpacity(0.03),
            baseBgColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Subtle Glassmorphic shape
          Positioned(
            right: -30,
            bottom: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _themeColor.withOpacity(0.15),
                    Colors.transparent,
                  ]
                )
              ),
            ),
          ),
          Column(children: children),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _themeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _themeColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 56,
      color: Colors.grey.withOpacity(0.15),
    );
  }
}
