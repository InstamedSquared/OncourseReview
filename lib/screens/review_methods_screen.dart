import 'package:flutter/material.dart';
import 'method_competency_list_screen.dart';

class ReviewMethodsScreen extends StatelessWidget {
  const ReviewMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : const Color(0xFFF5F7FA);
    final themeColor = const Color(0xFF89D3EE);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review Methods',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a method to test your knowledge and track your progress.',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              
              _buildMethodCard(
                context: context,
                title: 'Practice Mode',
                description: 'Questions are grouped by competencies. Questions will be random without a timer. Correct answers are shown immediately after you answer.',
                icon: Icons.menu_book_rounded,
                color: const Color(0xFF4CAF50),
                isDark: isDark,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const MethodCompetencyListScreen(examType: 'Practice Mode'),
                  ));
                },
              ),
              
              _buildMethodCard(
                context: context,
                title: 'Assessment',
                description: 'Questions are grouped by competencies without a timer. A complete summary and your exam result will be shown at the end.',
                icon: Icons.timer_outlined,
                color: const Color(0xFF2196F3),
                isDark: isDark,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const MethodCompetencyListScreen(examType: 'Assessment'),
                  ));
                },
              ),
              
              _buildMethodCard(
                context: context,
                title: 'Pre-Board',
                description: 'Simulate the actual Board Examination. You will be tested with randomly selected mixed questions under a strict time limit.',
                icon: Icons.assignment_turned_in_outlined,
                color: const Color(0xFF9C27B0),
                isDark: isDark,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const MethodCompetencyListScreen(examType: 'Pre-Board'),
                  ));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    // Premium styling variables
    final baseBgColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final shadowColor = isDark ? Colors.black.withOpacity(0.8) : color.withOpacity(0.3);
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : color.withOpacity(0.15);
    final contentTextColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 4, right: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? color.withOpacity(0.2) : color.withOpacity(0.08),
            baseBgColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Stack(
            children: [
              // Glassmorphic background shapes
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withOpacity(0.3),
                        Colors.transparent,
                      ]
                    )
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: color.withOpacity(isDark ? 0.2 : 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withOpacity(0.3)),
                        boxShadow: [
                          if (!isDark) BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Center(
                        child: Icon(icon, color: isDark ? color : color.withOpacity(0.9), size: 32),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: contentTextColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 14,
                              color: subtitleColor,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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
}
