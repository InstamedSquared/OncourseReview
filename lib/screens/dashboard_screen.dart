import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'exam_result_details_screen.dart';
import 'event_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _dashboardSummary;
  bool _isLoadingSummary = true;
  String _summaryError = '';
  
  // Premium Refresh State
  double _pullDistance = 0.0;
  bool _hasTriggeredHaptic = false;
  final double _refreshThreshold = 100.0;

  final Color _primaryRed = const Color(0xFF89D3EE);

  @override
  void initState() {
    super.initState();
    _loadUserAndSummary();
    ApiService.updateNotifier.addListener(_onGlobalUpdate);
  }

  @override
  void dispose() {
    ApiService.updateNotifier.removeListener(_onGlobalUpdate);
    super.dispose();
  }

  void _onGlobalUpdate() {
    if (mounted && _user != null) {
      final studentId = _user!['id']?.toString() ?? '';
      if (studentId.isNotEmpty) {
        _fetchSummary(studentId);
      }
    }
  }

  Future<void> _loadUserAndSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson != null) {
      final userMap = jsonDecode(userJson);
      setState(() {
        _user = userMap;
      });
      // Fetch summary
      final studentId = userMap['id']?.toString() ?? '';
      if (studentId.isNotEmpty) {
        _fetchSummary(studentId);
      } else {
        setState(() {
          _isLoadingSummary = false;
        });
      }
    } else {
      setState(() {
        _isLoadingSummary = false;
      });
    }
  }

  Future<void> _fetchSummary(String studentId, {bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoadingSummary = true;
        _summaryError = '';
      });
    }
    try {
      final response = await ApiService.getDashboardSummary(studentId);
      if (response['success'] == true) {
        if (mounted) {
          setState(() {
            _dashboardSummary = response;
            _isLoadingSummary = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _summaryError = response['message'] ?? 'Failed to load dashboard data.';
            _isLoadingSummary = false;
          });
          if (isRefresh) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text(_summaryError), backgroundColor: Colors.redAccent),
             );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _summaryError = 'Connection error.';
          _isLoadingSummary = false;
        });
        if (isRefresh) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Connection error. Please try again.'), backgroundColor: Colors.redAccent),
           );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            // Track overscroll/pull distance
            if (notification.metrics.pixels < 0) {
              setState(() {
                _pullDistance = notification.metrics.pixels.abs();
              });
              
              // Trigger haptic when threshold is reached
              if (_pullDistance >= _refreshThreshold && !_hasTriggeredHaptic) {
                HapticFeedback.mediumImpact();
                _hasTriggeredHaptic = true;
              }
            } else if (_pullDistance != 0) {
              setState(() => _pullDistance = 0);
            }
          }
          if (notification is ScrollEndNotification) {
            if (_pullDistance >= _refreshThreshold) {
              final studentId = _user!['id']?.toString() ?? '';
              if (studentId.isNotEmpty) {
                _fetchSummary(studentId, isRefresh: true);
              }
            }
            setState(() {
              _pullDistance = 0;
              _hasTriggeredHaptic = false;
            });
          }
          return false;
        },
        child: Stack(
          children: [
            // 1. The Main Scrollable Content
            RefreshIndicator(
              // Keep standard one as fallback but hide it with transparent color
              // This is a safety measure so standard refresh still works if gesture fails
              backgroundColor: Colors.transparent,
              color: Colors.transparent,
              onRefresh: () async {
                 final studentId = _user!['id']?.toString() ?? '';
                 if (studentId.isNotEmpty) {
                   await _fetchSummary(studentId, isRefresh: true);
                 }
              },
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8), // Minimal room for custom header
            // Simple Greeting Header
            Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 20,
                        color: textColor,
                        fontFamily: 'Outfit', // Or whatever font you use
                      ),
                      children: [
                        TextSpan(
                          text: _getGreetingMessage().replaceAll(',', ''),
                          style: const TextStyle(fontWeight: FontWeight.w400),
                        ),
                        TextSpan(
                          text: ' ${_user!['fn']},',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(
                  _getGreetingIcon(),
                  size: 28,
                  color: Colors.amber.shade600,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Course info card
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeOutBack,
              child: _buildEnrolledCourseCard(isDark),
            ),
            
            const SizedBox(height: 24),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeOutCubic,
              child: _buildStatsRow(isDark),
            ),
            const SizedBox(height: 30),

             // Recent Activity Section
            if (_isLoadingSummary || (_dashboardSummary != null && (_dashboardSummary!['recent_exams'] as List).isNotEmpty)) ...[
               AnimatedSwitcher(
                 duration: const Duration(milliseconds: 600),
                 child: Column(
                   key: ValueKey('recent_${_isLoadingSummary}'),
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     _buildSectionHeader('Recent Activity', textColor),
                     const SizedBox(height: 12),
                     _buildRecentActivityCarousel(isDark),
                     const SizedBox(height: 24),
                   ],
                 ),
               ),
            ],

            // Upcoming Event
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Column(
                key: ValueKey('event_${_isLoadingSummary}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildSectionHeader('Upcoming Event', textColor),
                   const SizedBox(height: 12),
                   _buildUpcomingEventCard(isDark, subtitleColor),
                   const SizedBox(height: 24),
                ],
              ),
            ),


                  ],
                ),
              ),
            ),
            
            // 2. The Premium Refresh Header (Frosted Glass Disc)
            _buildPremiumRefreshHeader(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumRefreshHeader(bool isDark) {
    // Spatial calculations: scale and rotate based on pull distance
    double opacity = (_pullDistance / _refreshThreshold).clamp(0.0, 1.0);
    double scale = 0.5 + (0.5 * opacity);
    double rotation = (_pullDistance / 50.0); // subtle spin
    
    return Positioned(
      top: -60 + (_pullDistance * 0.8).clamp(0.0, 110.0),
      left: 0,
      right: 0,
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rotation,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _pullDistance >= _refreshThreshold 
                            ? _primaryRed 
                            : Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    // child: Center(
                    //   child: _isLoadingSummary && _pullDistance == 0
                    //       ? SizedBox(
                    //           width: 20,
                    //           height: 20,
                    //           child: CircularProgressIndicator(
                    //             strokeWidth: 2.5,
                    //             valueColor: AlwaysStoppedAnimation<Color>(_primaryRed),
                    //           ),
                    //         )
                    //       : Icon(
                    //           Icons.refresh_rounded,
                    //           color: _pullDistance >= _refreshThreshold ? _primaryRed : Colors.white70,
                    //           size: 24,
                    //         ),
                    // ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning,';
    } else if (hour < 17) {
      return 'Good afternoon,';
    } else {
      return 'Good evening,';
    }
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return Icons.wb_sunny;
    } else if (hour < 17) {
      return Icons.cloud;
    } else {
      return Icons.nights_stay;
    }
  }

  Widget _buildEnrolledCourseCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryRed, 
            const Color(0xFF6BBAE3), // Slightly darker/richer shade for depth
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryRed.withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _isLoadingSummary 
        ? _buildShimmerOverlay(
            child: _buildEnrolledCourseContent(),
          )
        : _buildEnrolledCourseContent(),
    );
  }

  Widget _buildEnrolledCourseContent() {
    return Stack(
      children: [
        // Glassmorphic background shapes
        Positioned(
          right: -30,
          top: -30,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
        ),
        Positioned(
          left: -20,
          bottom: -40,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
        ),
        
        // Foreground Content
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'ACTIVE JOURNEY',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _user!['class_name'] ?? 'N/A',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Level: ${_user!['level_name'] ?? 'N/A'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    String assessments = '—';
    String preboards = '—';

    if (_dashboardSummary != null && _dashboardSummary!['summary'] != null) {
      assessments = _dashboardSummary!['summary']['total_assessments']?.toString() ?? '0';
      preboards = _dashboardSummary!['summary']['total_preboards']?.toString() ?? '0';
    } else if (_isLoadingSummary) {
      assessments = '...';
      preboards = '...';
    }

    return _isLoadingSummary 
      ? _buildShimmerOverlay(
          child: _buildStatsContent(assessments, preboards, cardColor, textColor),
        )
      : _buildStatsContent(assessments, preboards, cardColor, textColor);
  }

  Widget _buildStatsContent(String assessments, String preboards, Color cardColor, Color textColor) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.assignment,
            label: 'Assessments',
            value: assessments,
            color: const Color(0xFF2196F3),
            cardColor: cardColor,
            textColor: textColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.fact_check,
            label: 'Pre-Board',
            value: preboards,
            color: const Color(0xFF4CAF50),
            cardColor: cardColor,
            textColor: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityCarousel(bool isDark) {
    if (_isLoadingSummary) {
      return _buildShimmerOverlay(
        child: SizedBox(
          height: 140, 
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (_, __) => Container(
              width: 220,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      );
    }
    
    final recentExams = _dashboardSummary!['recent_exams'] as List<dynamic>? ?? [];
    if (recentExams.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 175, // Increased height to prevent shadow clipping
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: recentExams.length,
        itemBuilder: (context, index) {
          final item = recentExams[index];
          return _buildRecentItemCard(item, isDark);
        },
      ),
    );
  }

  String _formatDateTime(String? datetimeStr) {
    if (datetimeStr == null || datetimeStr.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(datetimeStr);
      final monthNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final month = monthNames[dateTime.month - 1];
      final day = dateTime.day;
      final year = dateTime.year;
      int hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'pm' : 'am';
      
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour -= 12;
      }
      
      return '$month $day, $year\n$hour:$minute $period';
    } catch (e) {
      return datetimeStr.split(' ')[0]; // fallback
    }
  }

  Widget _buildRecentItemCard(dynamic item, bool isDark) {
    final String name = item['name']?.toString() ?? 'Unknown';
    final String type = item['exam_type']?.toString() ?? 'assessment';
    final String status = item['status']?.toString() ?? 'Failed';
    final double rawAve = double.tryParse(item['ave']?.toString() ?? '0') ?? 0;
    
    final bool isPassed = status.toUpperCase() == 'PASSED' || rawAve >= 60;
    final Color progressColor = isPassed ? Colors.green.shade500 : Colors.orange.shade500;
    final int displayAve = rawAve < 60 && rawAve > 0 ? 60 : rawAve.round(); // Apply 60% floor hack if not 0
    final String date = _formatDateTime(item['dt_inserted']?.toString());

    // Premium styling variables - significantly enhanced vibrancy
    final baseBgColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final typeColor = type == 'assessment' ? Colors.blue.shade100 : Colors.purple.shade100;
    final gradientEndColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100;
    
    final shadowColor = isDark ? Colors.black.withOpacity(0.8) : typeColor.withOpacity(0.6);
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : typeColor.withOpacity(0.5);

    return Container(
      width: 220, 
      margin: const EdgeInsets.only(right: 16, bottom: 20), // Extra bottom margin for dramatic shadow
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? typeColor.withOpacity(0.15) : typeColor.withOpacity(0.3),
            baseBgColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: shadowColor, 
            blurRadius: 12, 
            offset: const Offset(0, 6)
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          highlightColor: progressColor.withOpacity(0.1),
          splashColor: progressColor.withOpacity(0.2),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExamResultDetailsScreen(
                  recordId: int.tryParse(item['id']?.toString() ?? '0') ?? 0,
                  type: type,
                ),
              ),
            );
          },
          child: Stack(
            children: [
              // Glassmorphic background shapes - dramatically increased opacity
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (type == 'assessment' ? Colors.blue : Colors.purple).withOpacity(0.25),
                        Colors.transparent,
                      ]
                    )
                  ),
                ),
              ),
              Positioned(
                left: -10,
                bottom: -20,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                  ),
                ),
              ),
              
              // Frontend content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Header (Title & Badge)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.2,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white.withOpacity(0.95) : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: type == 'assessment' ? Colors.blue.withOpacity(0.15) : Colors.purple.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            type == 'assessment' ? 'Asmt' : 'PreB',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: type == 'assessment' ? Colors.blue.shade600 : Colors.purple.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Footer (Date, Status, Ring)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1.5),
                                    child: Icon(Icons.calendar_today, size: 12, color: isDark ? Colors.white54 : Colors.grey.shade500),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      date,
                                      style: TextStyle(
                                        fontSize: 10, 
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                        color: isDark ? Colors.white54 : Colors.grey.shade600
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: progressColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: progressColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: CircularProgressIndicator(
                                value: displayAve / 100,
                                strokeWidth: 4.5,
                                backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Text(
                              '$displayAve%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingEventCard(bool isDark, Color subtitleColor) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    if (_isLoadingSummary) {
      return _buildShimmerOverlay(
        child: Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: _buildFallbackGradient(), 
        ),
      );
    }

    if (_dashboardSummary == null || _dashboardSummary!['upcoming_event'] == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: subtitleColor.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(Icons.event_busy, size: 48, color: subtitleColor.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(
              'No upcoming events scheduled',
              style: TextStyle(color: subtitleColor, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    final evt = _dashboardSummary!['upcoming_event'];
    final coverImage = evt['cover_image']?.toString() ?? '';
    final title = evt['title']?.toString() ?? 'Event';
    final venue = evt['venue']?.toString() ?? '';
    final dateOn = evt['date_on']?.toString() ?? '';

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.black.withOpacity(0.08), 
            blurRadius: 15, 
            offset: const Offset(0, 8)
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image or Gradient
          if (coverImage.isNotEmpty)
            Image.network(
              coverImage,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackGradient(),
            )
          else 
            _buildFallbackGradient(),

          // Dark Overlay Gradient for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.85),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // Content Overlay
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Event Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primaryRed,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Text(
                    'NEXT EVENT',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                
                // Date and Venue Row
                Row(
                  children: [
                    // Date
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month, size: 16, color: Colors.white.withOpacity(0.8)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              dateOn,
                              style: TextStyle(
                                fontSize: 13, 
                                color: Colors.white.withOpacity(0.95), 
                                fontWeight: FontWeight.w500
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (venue.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      // Venue
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.white.withOpacity(0.8)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                venue,
                                style: TextStyle(
                                  fontSize: 13, 
                                  color: Colors.white.withOpacity(0.95), 
                                  fontWeight: FontWeight.w500
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Interaction ripple
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventDetailsScreen(
                      event: Map<String, dynamic>.from(evt),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerOverlay({required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -2.0, end: 2.0),
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeInOutSine,
      builder: (context, value, _) {
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                (value - 0.5).clamp(0.0, 1.0),
                value.clamp(0.0, 1.0),
                (value + 0.5).clamp(0.0, 1.0),
              ],
              colors: [
                Colors.white.withOpacity(0.0),
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.0),
              ],
            ).createShader(rect);
          },
          child: child,
        );
      },
      onEnd: () {
        if (mounted && _isLoadingSummary) {
          Future.delayed(Duration.zero, () {
            if (mounted) setState(() {});
          });
        }
      },
    );
  }

  Widget _buildFallbackGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.indigo.shade400, // Lighter to combat dark overlay
            Colors.deepPurple.shade800
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Glassmorphic background shapes - bumped up opacity to pierce through overlay
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.25),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: 20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
          ),
          const Center(
            child: Icon(Icons.stars_rounded, color: Colors.white30, size: 90),
          ),
        ],
      ),
    );
  }
}



/// Stat card widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color cardColor;
  final Color textColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.cardColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    // Generate a softer, premium gradient based on the passed color
    final gradientColors = [
      color.withOpacity(0.85),
      color,
    ];

    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative background circle 1
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
          ),
          // Decorative background circle 2
          Positioned(
            right: -10,
            bottom: -30,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          
          // Main Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
