import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'quiz_engine_screen.dart';
import 'exam_history_screen.dart';

class MethodCompetencyListScreen extends StatefulWidget {
  final String examType; // 'Practice Mode', 'Assessment', 'Pre-Board'

  const MethodCompetencyListScreen({super.key, required this.examType});

  @override
  State<MethodCompetencyListScreen> createState() => _MethodCompetencyListScreenState();
}

class _MethodCompetencyListScreenState extends State<MethodCompetencyListScreen> {
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _competencies = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _limit = 5;
  String _errorMessage = '';
  int _cLevel = 0;

  @override
  void initState() {
    super.initState();
    _initAndLoadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initAndLoadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('user');
      if (userStr != null) {
        final user = jsonDecode(userStr);
        // The c_level field correlates to course_level_id from student data
        _cLevel = int.tryParse(user['course_level_id']?.toString() ?? '0') ?? 0;
      }
      
      if (_cLevel == 0) {
        setState(() {
          _errorMessage = "Course level not found. Cannot load competencies.";
          _isLoading = false;
        });
        return;
      }

      await _fetchCompetencies(refresh: true);
    } catch (e) {
      setState(() {
         _errorMessage = "Failed to initialize: $e";
         _isLoading = false;
      });
    }
  }

  Future<void> _fetchCompetencies({bool refresh = false, int? loadPage}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      if (loadPage != null) {
        _currentPage = loadPage;
      }
    });

    final response = await ApiService.getReviewer(
      cLevel: _cLevel,
      page: _currentPage,
      limit: _limit,
    );

    if (response['success'] == true) {
      final List<dynamic> data = response['data'] ?? [];
      final Map<String, dynamic> pagination = response['pagination'] ?? {};

      setState(() {
        _competencies = data; // Always replace for strict pagination
        _hasMore = pagination['has_more'] ?? false;
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = response['message'] ?? 'Failed to load competencies';
        _isLoading = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _fetchCompetencies();
    }
  }

  Future<void> _onRefresh() async {
    await _fetchCompetencies(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : const Color(0xFFF5F7FA);
    final themeColor = const Color(0xFF89D3EE);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('${widget.examType} - Select Competency', 
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        backgroundColor: themeColor,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(isDark, themeColor),
    );
  }

  Widget _buildBody(bool isDark, Color themeColor) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: themeColor));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: themeColor),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _fetchCompetencies(refresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_competencies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No Competencies Found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'There are no review materials available for your course level right now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: themeColor,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
              itemCount: _competencies.length,
              itemBuilder: (context, index) {
                final comp = _competencies[index];
                return _buildCompetencyCard(comp, isDark, themeColor);
              },
            ),
          ),
          
          // Pagination Controls
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous Button
                  TextButton.icon(
                    onPressed: _currentPage > 1
                        ? () {
                            _fetchCompetencies(loadPage: _currentPage - 1);
                          }
                        : null,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                    label: const Text('Prev'),
                    style: TextButton.styleFrom(
                      foregroundColor: themeColor,
                      disabledForegroundColor: Colors.grey,
                    ),
                  ),
                  
                  // Page Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Page $_currentPage',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                  ),
                  
                  // Next Button
                  TextButton(
                    onPressed: _hasMore
                        ? () {
                            _fetchCompetencies(loadPage: _currentPage + 1);
                          }
                        : null,
                    style: TextButton.styleFrom(
                      foregroundColor: themeColor,
                      disabledForegroundColor: Colors.grey,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Text('Next'),
                         SizedBox(width: 4),
                         Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompetencyCard(Map<String, dynamic> comp, bool isDark, Color themeColor) {
    final compName = comp['name']?.toString() ?? 'Competency';
    final compCode = comp['code']?.toString() ?? '';
    final compDesc = comp['description']?.toString() ?? 'No description available.';
    final maxQue = comp['max_que']?.toString() ?? '0';
    
    // Premium styling variables
    final baseBgColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final gradientEndColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50;
    final shadowColor = isDark ? Colors.black.withOpacity(0.8) : Colors.black.withOpacity(0.06);
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : themeColor.withOpacity(0.15);
    final contentTextColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? themeColor.withOpacity(0.15) : themeColor.withOpacity(0.06),
            baseBgColor,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final compId = int.tryParse(comp['id']?.toString() ?? '0') ?? 0;
            if (compId > 0) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuizEngineScreen(
                    examId: compId,
                    examType: widget.examType,
                    compCode: compCode,
                    compName: compName,
                    maxQue: maxQue,
                  ),
                ),
              );
            }
          },
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
                        themeColor.withOpacity(isDark ? 0.25 : 0.1),
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
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: themeColor.withOpacity(0.3)),
                        boxShadow: [
                          if (!isDark) BoxShadow(color: themeColor.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Icon(Icons.assignment_outlined, color: isDark ? themeColor : themeColor.withOpacity(0.9), size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: themeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              compCode,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: themeColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Text(
                            compName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: contentTextColor,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            compDesc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : subtitleColor,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.white54 : Colors.black54,
                        size: 20,
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
