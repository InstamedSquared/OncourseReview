import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'events_screen.dart';
import 'reviewer_screen.dart';
import 'review_methods_screen.dart';
import 'profile_screen.dart';
import 'exam_history_screen.dart';
import 'login_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  Map<String, dynamic>? _user;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Color _primaryRed = const Color(0xFF89D3EE);

  final List<Widget> _screens = const [
    DashboardScreen(),
    EventsScreen(),
    ReviewerScreen(),
    ReviewMethodsScreen(),
    ProfileScreen(),
  ];

  final List<String> _titles = const [
    'Home',
    'Events',
    'Reviewer',
    'Review Methods',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson != null) {
      setState(() {
        _user = jsonDecode(userJson);
      });
      
      // Fetch full profile to get profile image
      final studentId = prefs.getString('student_id');
      if (studentId != null) {
        final result = await ApiService.getProfile(studentId);
        if (result['success'] == true) {
          if (mounted) {
            setState(() {
              // Merge full profile data into _user map so we get profile_image
              _user = result['profile'];
            });
          }
        }
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
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    final userName = _user != null
        ? '${_user!['fn'] ?? ''} ${_user!['ln'] ?? ''}'
        : 'Student';
    final userEmail = _user?['email'] ?? '';
    final userInitials = _user != null
        ? '${(_user!['fn'] ?? 'O')[0]}${(_user!['ln'] ?? 'C')[0]}'
        : 'OC';
    final profileImageUrl = _user?['profile_image'] ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(
            _titles[_currentIndex],
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
          titleSpacing: 0,
          backgroundColor: _primaryRed,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: const [],
        ),

        // ──────────────────────────────────────────────
        // Sidebar Drawer (simplified)
        // ──────────────────────────────────────────────
        // ──────────────────────────────────────────────
        // Sidebar Drawer (Premium Redesign)
        // ──────────────────────────────────────────────
        drawer: Drawer(
          width: MediaQuery.of(context).size.width * 0.8,
          backgroundColor: surfaceColor,
          child: Stack(
            children: [
              // Background Gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      isDark ? _primaryRed.withOpacity(0.15) : _primaryRed.withOpacity(0.1),
                      surfaceColor,
                    ],
                  ),
                ),
              ),
              
              // Glassmorphic background shapes
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _primaryRed.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                  ),
                ),
              ),

              Column(
                children: [
                  // Drawer header
                  UserAccountsDrawerHeader(
                    margin: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _primaryRed,
                          _primaryRed.withOpacity(0.8),
                        ],
                      ),
                    ),
                    currentAccountPicture: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        backgroundImage: profileImageUrl.isNotEmpty && profileImageUrl != 'http://localhost/oncourse/resources/assets/images/files/blank_profile.png'
                            ? NetworkImage(profileImageUrl)
                            : null,
                        child: profileImageUrl.isEmpty || profileImageUrl == 'http://localhost/oncourse/resources/assets/images/files/blank_profile.png'
                            ? Text(
                                userInitials,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              )
                            : null,
                      ),
                    ),
                    accountName: Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    accountEmail: Text(
                      userEmail,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Menu items Scrollable area
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      children: [
                        _DrawerItem(
                          icon: Icons.dashboard_outlined,
                          activeIcon: Icons.dashboard,
                          label: 'Dashboard',
                          isSelected: _currentIndex == 0,
                          textColor: textColor,
                          accentColor: _primaryRed,
                          onTap: () {
                            setState(() => _currentIndex = 0);
                            Navigator.pop(context);
                          },
                        ),
                        _DrawerItem(
                          icon: Icons.menu_book_outlined,
                          activeIcon: Icons.menu_book,
                          label: 'Reviewer',
                          isSelected: _currentIndex == 2,
                          textColor: textColor,
                          accentColor: _primaryRed,
                          onTap: () {
                            setState(() => _currentIndex = 2);
                            Navigator.pop(context);
                          },
                        ),
                        _DrawerItem(
                          icon: Icons.quiz_outlined,
                          activeIcon: Icons.quiz,
                          label: 'Methods',
                          isSelected: _currentIndex == 3,
                          textColor: textColor,
                          accentColor: _primaryRed,
                          onTap: () {
                            setState(() => _currentIndex = 3);
                            Navigator.pop(context);
                          },
                        ),
                        
                        _dividerWithPadding(subtitleColor),

                        // Exam History expandable section
                        Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: textColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.history, color: textColor.withOpacity(0.7), size: 18),
                            ),
                            title: Text(
                              'Exam History',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                letterSpacing: 0.2,
                              ),
                            ),
                            iconColor: textColor.withOpacity(0.5),
                            collapsedIconColor: textColor.withOpacity(0.5),
                            children: [
                              _buildSubTile(
                                icon: Icons.assignment_outlined,
                                label: 'Assessment',
                                textColor: textColor,
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => const ExamHistoryScreen(type: 'assessment', title: 'Assessment Results'),
                                  ));
                                },
                              ),
                              _buildSubTile(
                                icon: Icons.assignment_turned_in_outlined,
                                label: 'Pre-Board',
                                textColor: textColor,
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => const ExamHistoryScreen(type: 'preboard', title: 'Pre-Board Results'),
                                  ));
                                },
                              ),
                            ],
                          ),
                        ),

                        _dividerWithPadding(subtitleColor),

                        _DrawerItem(
                          icon: Icons.event_outlined,
                          activeIcon: Icons.event,
                          label: 'Events',
                          isSelected: _currentIndex == 1,
                          textColor: textColor,
                          accentColor: _primaryRed,
                          onTap: () {
                            setState(() => _currentIndex = 1);
                            Navigator.pop(context);
                          },
                        ),
                        _DrawerItem(
                          icon: Icons.help_outline,
                          activeIcon: Icons.help,
                          label: 'FAQ',
                          textColor: textColor,
                          accentColor: _primaryRed,
                          onTap: () {
                            Navigator.pop(context);
                            // TODO: Navigate to FAQ screen
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

                  // Footer / Logout Section (Fixed at bottom)
                  Container(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.red.withOpacity(0.12) : Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withOpacity(0.15)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.pop(context);
                          _handleLogout();
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, color: Colors.redAccent, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Logout',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ──────────────────────────────────────────────
        // Body — IndexedStack to preserve tab state
        // ──────────────────────────────────────────────
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),

        // ──────────────────────────────────────────────
        // Bottom Navigation Bar
        // ──────────────────────────────────────────────
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: surfaceColor,
            selectedItemColor: _primaryRed,
            unselectedItemColor: subtitleColor,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.event_outlined),
                activeIcon: Icon(Icons.event),
                label: 'Events',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.menu_book_outlined),
                activeIcon: Icon(Icons.menu_book),
                label: 'Reviewer',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.quiz_outlined),
                activeIcon: Icon(Icons.quiz),
                label: 'Methods',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
  /// Helper to build sub-items for ExpansionTile
  Widget _buildSubTile({
    required IconData icon,
    required String label,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(icon, color: textColor.withOpacity(0.5), size: 18),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: textColor.withOpacity(0.9),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      onTap: onTap,
    );
  }

  Widget _dividerWithPadding(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(color: color.withOpacity(0.15), indent: 20, endIndent: 20, thickness: 0.5),
    );
  }
}

/// Reusable drawer list item
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool isSelected;
  final Color textColor;
  final Color accentColor;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.isSelected = false,
    required this.textColor,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? accentColor.withOpacity(0.12) : Colors.transparent,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withOpacity(0.2) : textColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isSelected ? (activeIcon ?? icon) : icon,
            color: isSelected ? accentColor : textColor.withOpacity(0.7),
            size: 20,
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentColor : textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        dense: true,
        onTap: onTap,
      ),
    );
  }
}
