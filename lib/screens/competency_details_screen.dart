import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CompetencyDetailsScreen extends StatefulWidget {
  final int competencyId;

  const CompetencyDetailsScreen({super.key, required this.competencyId});

  @override
  State<CompetencyDetailsScreen> createState() => _CompetencyDetailsScreenState();
}

class _CompetencyDetailsScreenState extends State<CompetencyDetailsScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  
  Map<String, dynamic>? _metadata;
  Map<String, dynamic>? _navigation;
  List<dynamic> _questions = [];

  @override
  void initState() {
    super.initState();
    _fetchDetails(widget.competencyId);
  }

  Future<void> _fetchDetails(int examId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiService.getCompetencyDetails(examId);
      
      if (response['success'] == true) {
        setState(() {
          _metadata = response['metadata'];
          _navigation = response['navigation'];
          _questions = response['questions'] ?? [];
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
    final backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final themeColor = const Color(0xFF89D3EE);
    
    final String compName = _metadata != null ? (_metadata!['name'] ?? 'Questionnaire') : 'Loading...';
    
    int prevId = 0;
    int nextId = 0;
    if (_navigation != null) {
      prevId = int.tryParse(_navigation!['prev_id']?.toString() ?? '0') ?? 0;
      nextId = int.tryParse(_navigation!['next_id']?.toString() ?? '0') ?? 0;
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(compName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: themeColor,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: prevId > 0 ? () => _fetchDetails(prevId) : null,
            color: prevId > 0 ? Colors.black : Colors.black26,
            tooltip: 'Previous Competency',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: nextId > 0 ? () => _fetchDetails(nextId) : null,
            color: nextId > 0 ? Colors.black : Colors.black26,
            tooltip: 'Next Competency',
          ),
        ],
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
                onPressed: () => _fetchDetails(widget.competencyId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Center(
        child: Text(
          'No questions available for this competency.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final q = _questions[index];
        return _buildQuestionCard(q, index + 1, isDark);
      },
    );
  }

  Widget _buildQuestionCard(dynamic q, int index, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    final String question = q['question'] ?? '';
    final String correct = q['correct'] ?? '';
    final String wa = q['wa'] ?? '';
    final String wb = q['wb'] ?? '';
    final String wc = q['wc'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: dividerColor)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index. ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.4,
                  ),
                ),
                Expanded(
                  child: Text(
                    question,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Fixed Options (a: Correct, b/c/d: Wrong)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOptionRow('a.', correct, isCorrect: true, isDark: isDark),
                const SizedBox(height: 12),
                _buildOptionRow('b.', wa, isCorrect: false, isDark: isDark),
                const SizedBox(height: 12),
                _buildOptionRow('c.', wb, isCorrect: false, isDark: isDark),
                const SizedBox(height: 12),
                _buildOptionRow('d.', wc, isCorrect: false, isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow(String letter, String text, {required bool isCorrect, required bool isDark}) {
    if (text.isEmpty) return const SizedBox.shrink();

    final Color iconColor = isCorrect ? Colors.green : Colors.red;
    final IconData icon = isCorrect ? Icons.check : Icons.close;
    // In the web app styling, correct options might be default text color, and incorrect options are sometimes red.
    // For readability, we will keep the text color standard but slightly dimmer for wrong options, paired with the strong icon.
    final Color textColor = isCorrect 
        ? (isDark ? Colors.white : Colors.black87) 
        : (isDark ? Colors.red.shade300 : Colors.red.shade700);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          letter,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black54,
            height: 1.4,
          ),
        ),
        const SizedBox(width: 6),
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: textColor,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
