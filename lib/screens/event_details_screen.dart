import 'package:flutter/material.dart';

class EventDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;
    final themeColor = const Color(0xFF89D3EE);

    // Premium styling variables
    final baseBgColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final shadowColor = isDark ? Colors.black.withOpacity(0.8) : themeColor.withOpacity(0.3);
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : themeColor.withOpacity(0.15);

    final title = event['title'] ?? 'Untitled Event';
    final subTitle = event['sub_title'] ?? '';
    final venue = event['venue'] ?? '';
    final dateOn = event['date_on'] ?? '';
    final author = event['author'] ?? 'Admin';
    final coverImage = event['cover_image'] ?? '';
    final description = event['description'] ?? 'No description provided.';
    final hasImage = coverImage.toString().isNotEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Event Details'),
        backgroundColor: themeColor,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            if (hasImage)
              Image.network(
                coverImage,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.indigo.shade400, Colors.deepPurple.shade800],
                    ),
                  ),
                  child: const Icon(Icons.stars_rounded, color: Colors.white30, size: 80),
                ),
              ),

            // Content
            Container(
              transform: hasImage ? Matrix4.translationValues(0, -20, 0) : null,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: hasImage
                    ? const BorderRadius.vertical(top: Radius.circular(20))
                    : BorderRadius.zero,
              ),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  
                  if (subTitle.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                      child: Text(
                        subTitle,
                        style: TextStyle(
                          fontSize: 16,
                          color: subtitleColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Event Details Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          isDark ? themeColor.withOpacity(0.15) : themeColor.withOpacity(0.05),
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
                                  themeColor.withOpacity(0.25),
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
                        
                        // Foreground Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: themeColor.withOpacity(isDark ? 0.2 : 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: themeColor.withOpacity(0.3)),
                                    ),
                                    child: Icon(Icons.calendar_today, size: 20, color: isDark ? themeColor : themeColor.withOpacity(0.9)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Date & Time', style: TextStyle(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(dateOn, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Divider(color: borderColor, height: 1),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: themeColor.withOpacity(isDark ? 0.2 : 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: themeColor.withOpacity(0.3)),
                                    ),
                                    child: Icon(Icons.location_on, size: 20, color: isDark ? themeColor : themeColor.withOpacity(0.9)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Venue', style: TextStyle(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(venue.toString().isNotEmpty ? venue : 'TBA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Description Header
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: themeColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'About This Event',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Description Body
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          isDark ? themeColor.withOpacity(0.1) : themeColor.withOpacity(0.03),
                          baseBgColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor.withOpacity(isDark ? 0.3 : 0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Subtle Glassmorphic background shape
                        Positioned(
                          right: -50,
                          top: -50,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  themeColor.withOpacity(0.15),
                                  Colors.transparent,
                                ]
                              )
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: _buildDescriptionBody(description, textColor, themeColor),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionBody(String rawText, Color textColor, Color themeColor) {
    String cleanText = _stripHtmlTags(rawText);
    if (cleanText.isEmpty) {
      return Text('No description provided.', style: TextStyle(color: textColor));
    }

    // Extract first letter for drop cap. We must ignore HTML tags when finding the first letter.
    final rawTextNoTags = cleanText.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final firstLetter = rawTextNoTags.isNotEmpty ? rawTextNoTags.substring(0, 1) : '';

    String restOfText = cleanText;
    if (firstLetter.isNotEmpty) {
      int firstIdx = cleanText.indexOf(firstLetter);
      if (firstIdx != -1) {
         restOfText = cleanText.substring(0, firstIdx) + cleanText.substring(firstIdx + 1);
      }
    }

    return RichText(
      textAlign: TextAlign.left,
      text: TextSpan(
        children: [
          if (firstLetter.isNotEmpty)
            TextSpan(
              text: firstLetter,
              style: TextStyle(
                fontSize: 48,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: themeColor,
              ),
            ),
          ..._parseHtmlToTextSpans(restOfText.trim(), textColor),
        ],
      ),
    );
  }

  // Parses a string containing <b>, <strong>, <h3> tags into a list of TextSpans
  List<TextSpan> _parseHtmlToTextSpans(String text, Color textColor) {
    final List<TextSpan> spans = [];
    
    // We split the string by any tag: <b>, </b>, <strong>, </strong>, <h3>, </h3>
    // This allows us to handle unclosed tags gracefully.
    final RegExp tagExp = RegExp(r'<(/?)(b|strong|h3)>', caseSensitive: false);
    
    int lastMatchEnd = 0;
    bool isBold = false;
    bool isH3 = false;
    
    for (final Match m in tagExp.allMatches(text)) {
      // Add normal text before the tag
      if (m.start > lastMatchEnd) {
        final content = text.substring(lastMatchEnd, m.start);
        if (content.isNotEmpty) {
          spans.add(TextSpan(
            text: content,
            style: TextStyle(
              fontSize: isH3 ? 18 : 16,
              height: 1.8,
              letterSpacing: 0.3,
              fontWeight: (isBold || isH3) ? FontWeight.bold : FontWeight.normal,
              color: (isBold || isH3) ? textColor : textColor.withOpacity(0.9),
            ),
          ));
        }
      }
      
      // Update state based on the tag
      final isClosing = m.group(1) == '/';
      final tag = m.group(2)?.toLowerCase();
      
      if (tag == 'h3') {
        isH3 = !isClosing;
      } else if (tag == 'b' || tag == 'strong') {
        isBold = !isClosing;
      }
      
      lastMatchEnd = m.end;
    }
    
    // Add any remaining text after the last tag
    if (lastMatchEnd < text.length) {
      final content = text.substring(lastMatchEnd);
      if (content.isNotEmpty) {
        spans.add(TextSpan(
          text: content,
          style: TextStyle(
              fontSize: isH3 ? 18 : 16,
              height: 1.8,
              letterSpacing: 0.3,
              fontWeight: (isBold || isH3) ? FontWeight.bold : FontWeight.normal,
              color: (isBold || isH3) ? textColor : textColor.withOpacity(0.9),
          ),
        ));
      }
    }
    
    return spans;
  }

  // Helper method to strip simple HTML tags but preserve structural/bold tags
  String _stripHtmlTags(String htmlString) {
    if (htmlString.isEmpty) return htmlString;
    
    String parsedString = htmlString;
    
    // 1. Normalize tags to remove attributes so regex parsing works flawlessly
    parsedString = parsedString.replaceAll(RegExp(r'<h3[^>]*>', caseSensitive: false), '<h3>');
    parsedString = parsedString.replaceAll(RegExp(r'<b[^>]*>', caseSensitive: false), '<b>');
    parsedString = parsedString.replaceAll(RegExp(r'<strong[^>]*>', caseSensitive: false), '<strong>');

    // 2. Replace structural breaks with single newlines for tighter spacing
    parsedString = parsedString.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n\n');
    parsedString = parsedString.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n\n');
    parsedString = parsedString.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n');
    parsedString = parsedString.replaceAll(RegExp(r'</h1>|</h2>|</h4>|</h5>|</h6>', caseSensitive: false), '\n');
    
    // 3. Ensure <h3> blocks act as their own line to prevent text from mashing together
    parsedString = parsedString.replaceAll(RegExp(r'<h3>', caseSensitive: false), '\n<h3>');
    parsedString = parsedString.replaceAll(RegExp(r'</h3>', caseSensitive: false), '</h3>\n');
    
    // 4. Remove all tags EXCEPT b, strong, and h3
    parsedString = parsedString.replaceAll(RegExp(r'<(?!/?(b|strong|h3)\b)[^>]+>'), '');
    
    // 5. Decode HTML entities (basic)
    parsedString = parsedString.replaceAll('&nbsp;', ' ');
    parsedString = parsedString.replaceAll('&amp;', '&');
    parsedString = parsedString.replaceAll('&lt;', '<');
    parsedString = parsedString.replaceAll('&gt;', '>');
    parsedString = parsedString.replaceAll('&quot;', '"');
    parsedString = parsedString.replaceAll('&#39;', "'");
    
    // 6. Clean up excessive newlines (2 or more become just 1) to keep spacing compact
    parsedString = parsedString.replaceAll(RegExp(r'\n{2,}'), '\n');
    
    return parsedString.trim();
  }
}
