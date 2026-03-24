import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ExamResultDetailsScreen extends StatefulWidget {
  final int recordId;
  final String type; // 'assessment' or 'preboard'

  const ExamResultDetailsScreen({
    super.key,
    required this.recordId,
    required this.type,
  });

  @override
  State<ExamResultDetailsScreen> createState() => _ExamResultDetailsScreenState();
}

class _ExamResultDetailsScreenState extends State<ExamResultDetailsScreen> {
  bool _isLoading = true;
  String _errorMessage = '';

  Map<String, dynamic>? _metadata;
  List<dynamic> _questions = [];
  Map<int, dynamic> _xmap = {};

  final Color _themeColor = const Color(0xFF89D3EE);

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiService.getExamResultDetails(
        type: widget.type,
        id: widget.recordId,
      );

      if (response['success'] == true) {
        final metadata = response['metadata'];
        final questions = response['questions'] ?? [];
        
        // Parse xmap
        final String xmapStr = metadata['xmap'] ?? '[]';
        List<dynamic> parsedXmap = [];
        try {
          parsedXmap = jsonDecode(xmapStr);
        } catch (e) {
          // fallback
        }

        // Create a lookup for xmap by question id
        Map<int, dynamic> xmapLookup = {};
        for (var item in parsedXmap) {
          final qId = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
          xmapLookup[qId] = item;
        }

        setState(() {
          _metadata = metadata;
          _questions = questions;
          _xmap = xmapLookup;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load details.';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    final title = _metadata != null ? (_metadata!['code'] ?? 'Review Result') : 'Loading...';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: _themeColor,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _themeColor));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: _themeColor),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _themeColor,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_metadata == null) {
      return const Center(child: Text("Invalid record data."));
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 60),
      itemCount: _questions.length + 1, // +1 for summary header
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSummaryCard(isDark);
        }
        return _buildQuestionCard(_questions[index - 1], index, isDark);
      },
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final items = _metadata!['max_que']?.toString() ?? '0';
    final score = _metadata!['score']?.toString() ?? '0';
    final rawAve = _metadata!['ave'];
    
    double actualAve = double.tryParse(rawAve.toString()) ?? 0;
    if (actualAve < 60) actualAve = 60;
    final displayAve = actualAve.round();
    
    final status = _metadata!['status']?.toString() ?? 'Failed';
    final isPassed = status.toUpperCase() == 'PASSED';

    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Text(
            'SUMMARY - ${status.toUpperCase()}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isPassed ? Colors.green : Colors.red,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryItem('Items', items, textColor, isDark),
              _buildSummaryItem('Score', score, textColor, isDark),
              _buildSummaryItem('Average', '$displayAve%', textColor, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color textColor, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(dynamic q, int index, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    final qId = int.tryParse(q['id']?.toString() ?? '0') ?? 0;
    final String question = q['question'] ?? '';
    
    // Web app logic replication for mapping answers
    final xdata = _xmap[qId] ?? {};
    
    final cMap = {"a": 0, "b": 1, "c": 2, "d": 3, "0": 0, "1": 1, "2": 2, "3": 3};
    final uIdx = (xdata['a'] != null) ? cMap[xdata['a'].toString().toLowerCase()] : null;
    final caIdx = (xdata['ca'] != null) ? cMap[xdata['ca'].toString().toLowerCase()] : null;

    List<dynamic> tmpInd = (xdata['ans'] != null && xdata['ans'] is List) ? List.from(xdata['ans']) : [1, 2, 3, 4];
    
    // dynamic mapping fallback
    if (xdata['ans'] == null && caIdx != null) {
      final oldVal = tmpInd[caIdx];
      for (int i = 0; i < 4; i++) {
        if (tmpInd[i] == 4) tmpInd[i] = oldVal;
      }
      tmpInd[caIdx] = 4;
    }

    List<String> tmpAns = ['', '', '', ''];
    List<bool> isCorrectOpt = [false, false, false, false];
    int correctIndex = -1;

    for (int i = 0; i < 4; i++) {
      if (tmpInd.length > i) {
        if (tmpInd[i] == 1) { tmpAns[i] = q['wa'] ?? ''; }
        else if (tmpInd[i] == 2) { tmpAns[i] = q['wb'] ?? ''; }
        else if (tmpInd[i] == 3) { tmpAns[i] = q['wc'] ?? ''; }
        else if (tmpInd[i] == 4) { 
          tmpAns[i] = q['correct'] ?? ''; 
          isCorrectOpt[i] = true;
          correctIndex = i;
        }
      }
    }

    String rstLabel = "No Answer";
    String rstPrefix = "";
    bool isUserCorrect = false;

    if (uIdx != null) {
      isUserCorrect = (uIdx == caIdx);
      rstLabel = isUserCorrect ? "Correct" : "Wrong Answer";
      final aAbc = ["A - ", "B - ", "C - ", "D - "];
      rstPrefix = (uIdx < aAbc.length) ? aAbc[uIdx] : "";
    }

    final resultBannerColor = isUserCorrect
      ? (isDark ? Colors.green.withOpacity(0.15) : Colors.green.shade50)
      : (isDark ? Colors.red.withOpacity(0.15) : Colors.red.shade50);
      
    final resultBannerTextColor = isUserCorrect ? Colors.green.shade600 : Colors.red.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: dividerColor))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$index. ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor, height: 1.4)),
                Expanded(child: Text(question, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor, height: 1.4))),
              ],
            ),
          ),
          
          // Options
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOptionRow('a.', tmpAns[0], isCorrectOpt[0], uIdx == 0, isDark),
                const SizedBox(height: 12),
                _buildOptionRow('b.', tmpAns[1], isCorrectOpt[1], uIdx == 1, isDark),
                const SizedBox(height: 12),
                _buildOptionRow('c.', tmpAns[2], isCorrectOpt[2], uIdx == 2, isDark),
                const SizedBox(height: 12),
                _buildOptionRow('d.', tmpAns[3], isCorrectOpt[3], uIdx == 3, isDark),
              ],
            ),
          ),

          // Answer Result Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: resultBannerColor,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text(
                  'Answer : ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  '$rstPrefix$rstLabel',
                  style: TextStyle(fontWeight: FontWeight.w600, color: resultBannerTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow(String letter, String text, bool isCorrectItem, bool isUserSelected, bool isDark) {
    if (text.isEmpty) return const SizedBox.shrink();

    Color optTextColor = isCorrectItem ? _themeColor : (isDark ? Colors.red.shade300 : Colors.red.shade800);
    if (!isCorrectItem && !isUserSelected) {
        optTextColor = isDark ? Colors.white70 : Colors.black87;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          letter,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: optTextColor, height: 1.4),
        ),
        const SizedBox(width: 8),
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(top: 1, right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCorrectItem ? _themeColor : Colors.transparent,
            border: Border.all(
              color: isCorrectItem ? _themeColor : (isUserSelected ? Colors.red : Colors.grey.withOpacity(0.5)),
              width: 2,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: optTextColor, height: 1.4, fontWeight: isCorrectItem ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ],
    );
  }
}
