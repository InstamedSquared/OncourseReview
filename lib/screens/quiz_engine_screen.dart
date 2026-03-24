import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';

class QuizEngineScreen extends StatefulWidget {
  final int examId;
  final String examType; // 'Practice Mode', 'Assessment', 'Pre-Board'
  final String compCode;
  final String compName;
  final String maxQue;

  const QuizEngineScreen({
    super.key,
    required this.examId,
    required this.examType,
    required this.compCode,
    required this.compName,
    required this.maxQue,
  });

  @override
  State<QuizEngineScreen> createState() => _QuizEngineScreenState();
}

class _QuizEngineScreenState extends State<QuizEngineScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  
  // Tracking
  String _taken = "0"; // Comma separated IDs of taken questions
  List<Map<String, dynamic>> _xmap = []; // Stores user answers
  
  // Current Question State
  Map<String, dynamic>? _currentQuestion;
  bool _hasNext = true;
  int _currentNumber = 0;
  int _totalItems = 0;
  
  // Shuffled options for current question
  List<Map<String, dynamic>> _shuffledOptions = []; // [{letter, text, isCorrect}]
  String _correctLetter = 'a'; // Which letter the correct answer ended up at
  
  // Interaction State
  String? _selectedAnswer; // 'a', 'b', 'c', 'd'
  bool _showValidation = false; // Used in Practice mode to show correct answer before proceeding
  
  // Pre-Board Timer
  Timer? _timer;
  int _timeRemaining = 0; // in seconds, typically 1 hour = 3600
  String _durationStr = "01:00:00"; // Example default
  
  String _studentId = "";

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initEngine() async {
    final prefs = await SharedPreferences.getInstance();
    _studentId = prefs.getString('student_id') ?? "";

    if (widget.examType == 'Pre-Board') {
      // Mock duration 1 hour for Pre-Board. Real app might pull from API.
      _timeRemaining = 3600; 
      _startTimer();
    }
    
    _fetchNextQuestion();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        setState(() {
          _timeRemaining--;
        });
      } else {
        timer.cancel();
        _forceSubmitTest("Time's Up!");
      }
    });
  }

  String get _formattedTime {
    int h = _timeRemaining ~/ 3600;
    int m = (_timeRemaining % 3600) ~/ 60;
    int s = _timeRemaining % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _shuffleCurrentOptions() {
    if (_currentQuestion == null) return;
    final labels = ['a', 'b', 'c', 'd'];
    final options = [
      {'text': _currentQuestion!['correct'], 'isCorrect': true},
      {'text': _currentQuestion!['wa'], 'isCorrect': false},
      {'text': _currentQuestion!['wb'], 'isCorrect': false},
      {'text': _currentQuestion!['wc'], 'isCorrect': false},
    ];
    options.shuffle();
    _shuffledOptions = [];
    for (int i = 0; i < options.length; i++) {
      _shuffledOptions.add({
        'letter': labels[i],
        'text': options[i]['text'],
        'isCorrect': options[i]['isCorrect'],
      });
      if (options[i]['isCorrect'] == true) {
        _correctLetter = labels[i];
      }
    }
  }

  Future<void> _fetchNextQuestion() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _selectedAnswer = null;
      _showValidation = false;
    });

    try {
      final response = await ApiService.getPracticeQuestion(
        examId: widget.examId,
        taken: _taken,
      );

      if (response['success'] == true) {
        final progress = response['progress'];
        setState(() {
          _currentQuestion = response['question'];
          _taken = progress['taken']?.toString() ?? _taken;
          _hasNext = progress['has_next']?.toString() == "1";
          _currentNumber = progress['current'] != null ? int.parse(progress['current'].toString()) : _currentNumber + 1;
          _totalItems = progress['total'] != null ? int.parse(progress['total'].toString()) : int.parse(widget.maxQue);
          _shuffleCurrentOptions();
          _isLoading = false;
        });
      } else {
        if (response['message']?.contains('No more questions') == true) {
           _hasNext = false;
           _submitTest();
        } else {
          setState(() {
            _errorMessage = response['message'] ?? 'Failed to load question.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  String _stripHtml(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').trim();
  }

  void _onAnswerSelected(String val) {
    if (_showValidation) return; // Prevent changing answer after validation
    setState(() {
      _selectedAnswer = val;
    });
  }

  void _onNextPressed() {
    if (_selectedAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an answer')));
      return;
    }

    // In Practice Mode, handle the two-step flow:
    // Step 1: "Check Answer" → record answer + show validation
    // Step 2: "Next Question" → just proceed (don't add again)
    if (widget.examType == 'Practice Mode') {
      if (!_showValidation) {
        // Step 1: Record answer and show validation
        _xmap.add({
          'id': _currentQuestion!['id'],
          'a': _selectedAnswer,
          'ca': _correctLetter,
        });
        setState(() {
          _showValidation = true;
        });
        return;
      } else {
        // Step 2: Just proceed to next question (already recorded)
        if (_hasNext) {
          _fetchNextQuestion();
        } else {
          _submitTest();
        }
        return;
      }
    }

    // Assessment / Pre-Board: single-step flow
    _xmap.add({
      'id': _currentQuestion!['id'],
      'a': _selectedAnswer,
      'ca': _correctLetter,
    });

    if (_hasNext) {
      _fetchNextQuestion();
    } else {
      _submitTest();
    }
  }

  Future<void> _submitTest() async {
    setState(() => _isLoading = true);
    
    Map<String, dynamic> result;
    
    if (widget.examType == 'Pre-Board') {
      _timer?.cancel();
      // Calculate consume
      int consumedSecs = 3600 - _timeRemaining;
      int h = consumedSecs ~/ 3600;
      int m = (consumedSecs % 3600) ~/ 60;
      int s = consumedSecs % 60;
      String consumeStr = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      
      result = await ApiService.submitPreboard(
        studentId: _studentId,
        examId: widget.examId,
        taken: _taken,
        xmap: _xmap,
        duration: _durationStr,
        consume: consumeStr,
      );
    } else if (widget.examType == 'Assessment') {
      result = await ApiService.submitAssessment(
        studentId: _studentId,
        examId: widget.examId,
        taken: _taken,
        xmap: _xmap,
      );
    } else {
      // Practice mode just shows a local summary
      _showPracticeSummary();
      return;
    }

    setState(() => _isLoading = false);
    
    if (result['success'] == true) {
      ApiService.updateNotifier.value++; // Trigger dashboard refresh
      _showExamSummary(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Submission Failed')));
    }
  }

  void _forceSubmitTest(String reason) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason), backgroundColor: Colors.red));
    _submitTest();
  }

  void _showPracticeSummary() {
    int score = 0;
    for (var ans in _xmap) {
      if (ans['a'] == ans['ca']) score++;
    }
    
    // Match web app formula (practice.js lines 91-93):
    // t_ave defaults to 60. Actual = round((score/items)*100).
    // If actual > 60, show actual + "Passed". Otherwise show 60 + "Failed".
    int items = _xmap.length;
    int actualAverage = items > 0 ? ((score / items) * 100).round() : 0;
    int displayAverage = 60;
    bool passed = false;
    if (actualAverage > 60) {
      displayAverage = actualAverage;
      passed = true;
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          passed ? 'Passed' : 'Failed',
          style: TextStyle(
            color: passed ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Items: $items\nScore: $score\nAverage: $displayAverage%',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Go back to list
            },
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  void _showExamSummary(Map<String, dynamic> resultData) {
    // Compute score locally from xmap (same as Practice) for consistency
    int score = 0;
    for (var ans in _xmap) {
      if (ans['a'] == ans['ca']) score++;
    }
    int items = _xmap.length;
    
    // Same 60% floor formula used in web app (assessment.js lines 100-102)
    int actualAverage = items > 0 ? ((score / items) * 100).round() : 0;
    int displayAverage = 60;
    bool passed = false;
    if (actualAverage > 60) {
      displayAverage = actualAverage;
      passed = true;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          passed ? 'PASSED' : 'FAILED',
          style: TextStyle(
            color: passed ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        content: Text(
          'Items: $items\nScore: $score\nAverage: $displayAverage%',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Exit exam
            },
            child: const Text('Finish'),
          )
        ],
      ),
    );
  }

  // --- UI BUILDING ---
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = const Color(0xFF89D3EE);

    return WillPopScope(
      onWillPop: () async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Are you sure?'),
            content: const Text('Do you want to exit this exam? Your progress will be lost.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
            ],
          ),
        ) ?? false;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: Text('${widget.compCode} - ${widget.examType}', style: const TextStyle(fontSize: 16)),
          backgroundColor: themeColor,
          foregroundColor: Colors.black,
          actions: [
            if (widget.examType == 'Pre-Board')
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    _formattedTime,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                  ),
                ),
              )
          ],
        ),
        body: _buildBody(isDark, themeColor),
        bottomNavigationBar: (_currentQuestion != null)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton(
                  onPressed: (_selectedAnswer == null || _isLoading) ? null : _onNextPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    (widget.examType == 'Practice Mode' && !_showValidation)
                        ? 'Check Answer'
                        : (_hasNext ? 'Next Question' : 'Submit Exam'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
      ),
    );
  }

  Widget _buildBody(bool isDark, Color themeColor) {
    if (_isLoading && _currentQuestion == null) {
      return Center(child: CircularProgressIndicator(color: themeColor));
    }

    if (_errorMessage.isNotEmpty && _currentQuestion == null) {
      return Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)));
    }

    if (_currentQuestion == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question $_currentNumber of $_totalItems',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black54),
              ),
              if (_isLoading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 16),

          // Question Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Text(
              _stripHtml(_currentQuestion!['text'] ?? ''),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 24),

          // Shuffled Options
          ..._shuffledOptions.map((opt) => _buildOption(
            opt['letter'],
            opt['text'],
            isDark,
            themeColor,
            isCorrect: opt['isCorrect'] == true,
          )),
        ],
      ),
    );
  }

  Widget _buildOption(String value, String? rawText, bool isDark, Color themeColor, {required bool isCorrect}) {
    if (rawText == null || rawText.isEmpty) return const SizedBox.shrink();
    
    final text = _stripHtml(rawText);
    if (text.isEmpty) return const SizedBox.shrink();

    final isSelected = _selectedAnswer == value;
    
    Color borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    if (isSelected) {
      borderColor = themeColor;
      bgColor = themeColor.withOpacity(0.1);
    }

    if (_showValidation && isCorrect) {
      borderColor = Colors.green;
      bgColor = Colors.green.withOpacity(0.1);
    } else if (_showValidation && isSelected && !isCorrect) {
      borderColor = Colors.red;
      bgColor = Colors.red.withOpacity(0.1);
    }

    return GestureDetector(
      onTap: () => _onAnswerSelected(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? themeColor : Colors.grey),
                color: isSelected ? themeColor : Colors.transparent,
              ),
              child: Center(
                child: Text(
                  value.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            if (_showValidation && isCorrect)
              const Icon(Icons.check_circle, color: Colors.green),
            if (_showValidation && isSelected && !isCorrect)
              const Icon(Icons.cancel, color: Colors.red),
          ],
        ),
      ),
    );
  }
}
