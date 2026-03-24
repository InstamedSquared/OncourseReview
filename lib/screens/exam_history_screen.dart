import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'exam_result_details_screen.dart';

class ExamHistoryScreen extends StatefulWidget {
  final String type; // 'assessment' or 'preboard'
  final String title;
  final String? examId;
  
  const ExamHistoryScreen({
    super.key,
    required this.type,
    required this.title,
    this.examId,
  });

  @override
  State<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends State<ExamHistoryScreen> {
  List<dynamic> _records = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Pagination state
  int _page = 1;
  final int _limit = 10;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getString('student_id') ?? '0';

      final response = await ApiService.getExamHistory(
        type: widget.type,
        studentId: studentId,
        examId: widget.examId,
        page: _page,
        limit: _limit,
      );

      if (response['success'] == true) {
        final List<dynamic> newData = response['data'] ?? [];
        final pagination = response['pagination'] ?? {};
        setState(() {
          _records = newData;
          _hasMore = pagination['has_more'] ?? false;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load history.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  void _nextPage() {
    if (_hasMore) {
      setState(() {
        _page++;
      });
      _fetchHistory();
    }
  }

  void _previousPage() {
    if (_page > 1) {
      setState(() {
        _page--;
      });
      _fetchHistory();
    }
  }

  /// Match web app formula: floor at 60%, >60 = Passed
  int _computeDisplayAverage(dynamic ave) {
    double actual = double.tryParse(ave.toString()) ?? 0;
    if (actual < 60) return 60;
    return actual.round();
  }

  /// Helper to map month number to abbreviated name
  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  /// Parses and formats MySQL datetime (e.g., "2024-11-18 02:57:18") to "Nov 18, 2024 at 2:57 AM"
  String _formatDate(String? dtString) {
    if (dtString == null || dtString.isEmpty) return 'Unknown Date';
    try {
      final dt = DateTime.parse(dtString);
      final monthName = _getMonthName(dt.month);
      
      int hour = dt.hour;
      final amPm = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) hour = 12;
      else if (hour > 12) hour -= 12;
      
      final minute = dt.minute.toString().padLeft(2, '0');
      
      return '$monthName ${dt.day}, ${dt.year} at $hour:$minute $amPm';
    } catch (e) {
      return dtString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(0xFF89D3EE);
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: themeColor,
        foregroundColor: Colors.black,
      ),
      body: _buildBody(isDark, themeColor),
      bottomNavigationBar: _records.isNotEmpty ? _buildPaginationBar(isDark, surfaceColor, themeColor) : null,
    );
  }

  Widget _buildPaginationBar(bool isDark, Color surfaceColor, Color themeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              onPressed: _page > 1 ? _previousPage : null,
              icon: const Icon(Icons.arrow_back_ios, size: 14),
              label: const Text('Prev'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey.withOpacity(0.3),
              ),
            ),
            Text(
              'Page $_page',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            ElevatedButton(
              onPressed: _hasMore ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey.withOpacity(0.3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('Next'),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, Color themeColor) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: themeColor));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(_errorMessage, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchHistory,
                style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.black),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            Text(
              'No exam records yet.',
              style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : Colors.black45),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: themeColor,
      onRefresh: _fetchHistory,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 20), // Added bottom padding
        itemCount: _records.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Showing ${_records.length} result${_records.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            );
          }

          final r = _records[index - 1];
          final name = r['name']?.toString() ?? '';
          final code = r['code']?.toString() ?? '';
          final maxQue = r['max_que']?.toString() ?? '0';
          final score = r['score']?.toString() ?? '0';
          final rawAve = r['ave'];
          final displayAve = _computeDisplayAverage(rawAve);
          final status = r['status']?.toString() ?? 'Failed';
          final description = r['description']?.toString() ?? '';
          final isPassed = status.toLowerCase() == 'passed' || displayAve > 60;

          return _buildRecordCard(r, isDark, themeColor);
        },
      ),
    );
  }

  Widget _buildRecordCard(dynamic r, bool isDark, Color themeColor) {
    final name = r['name']?.toString() ?? '';
    final code = r['code']?.toString() ?? '';
    final description = r['description']?.toString() ?? '';
    final dtInserted = r['dt_inserted']?.toString();

    final scoreStr = r['score']?.toString() ?? '0';
    final maxQueStr = r['max_que']?.toString() ?? '0';
    final aveStr = r['ave']?.toString() ?? '0';
    final status = r['status']?.toString().toUpperCase() ?? 'UNKNOWN';

    final int displayAverage = _computeDisplayAverage(aveStr);
    final bool isPassed = displayAverage >= 60;
    
    // Check if the record actually has 0 items and 0 score
    final bool isZeroItems = maxQueStr == '0' && scoreStr == '0';

    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final shadowColor = isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.05);
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (!isZeroItems) {
              final recordId = int.tryParse(r['id']?.toString() ?? '0') ?? 0;
              if (recordId > 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExamResultDetailsScreen(
                      recordId: recordId,
                      type: widget.type,
                    ),
                  ),
                );
              }
            }
          },
          child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Top Color Bar based on status
            Container(
              height: 4,
              width: double.infinity,
              color: isZeroItems ? Colors.grey : (isPassed ? Colors.green.shade400 : Colors.red.shade400),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isNotEmpty ? name : 'Unknown Exam',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (code.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: themeColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  code,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? themeColor : Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isZeroItems 
                            ? (isDark ? Colors.grey.shade800 : Colors.grey.shade100)
                            : (isPassed ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isZeroItems 
                              ? Colors.grey.withOpacity(0.5)
                              : (isPassed ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5)),
                          ),
                        ),
                        child: Text(
                          isZeroItems ? 'N/A' : status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isZeroItems 
                              ? Colors.grey
                              : (isPassed ? Colors.green.shade600 : Colors.red.shade600),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 20),
                  
                  // Stats Row
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.blueGrey.shade50),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Items', maxQueStr, Icons.list_alt, isDark),
                        Container(width: 1, height: 30, color: isDark ? Colors.white12 : Colors.grey.shade300),
                        _buildStatItem('Score', scoreStr, Icons.check_circle_outline, isDark, 
                          color: isZeroItems ? null : (isPassed ? Colors.green.shade600 : Colors.red.shade600)),
                        Container(width: 1, height: 30, color: isDark ? Colors.white12 : Colors.grey.shade300),
                        _buildStatItem('Average', isZeroItems ? '0%' : '$displayAverage%', Icons.percent, isDark,
                          color: isZeroItems ? null : (isPassed ? Colors.green.shade600 : Colors.red.shade600)),
                      ],
                    ),
                  ),

                  // Optional DateTime Row at bottom
                  if (dtInserted != null && dtInserted.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Divider(color: borderColor, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: isDark ? Colors.white38 : Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(dtInserted),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white38 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, bool isDark, {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color ?? (isDark ? Colors.white70 : Colors.black54)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}
