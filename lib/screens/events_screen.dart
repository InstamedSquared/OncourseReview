import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'event_details_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final Color _themeColor = const Color(0xFF89D3EE);
  List<dynamic> _events = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreEvents();
    }
  }

  Future<void> _fetchEvents({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _events.clear();
        _hasMore = true;
      });
    }

    setState(() {
      _isLoading = _page == 1;
      _errorMessage = null;
    });

    final result = await ApiService.getEvents(page: _page, limit: 10);

    if (mounted) {
      setState(() {
        _isLoading = false;
        
        if (result['success'] == true) {
          if (refresh) {
            _events = result['events'] ?? [];
          } else {
            _events.addAll(result['events'] ?? []);
          }
          
          final pagination = result['pagination'];
          if (pagination != null) {
            _hasMore = pagination['has_more'] == true;
          } else {
            _hasMore = false;
          }
        } else {
          _errorMessage = result['message'] ?? 'Failed to load events';
        }
      });
    }
  }

  Future<void> _loadMoreEvents() async {
    setState(() {
      _isLoadingMore = true;
      _page++;
    });

    await _fetchEvents();

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      body: _buildBody(cardColor, textColor, subtitleColor, isDark),
    );
  }

  Widget _buildBody(Color cardColor, Color textColor, Color subtitleColor, bool isDark) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _themeColor));
    }

    if (_errorMessage != null && _events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: subtitleColor)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchEvents(refresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _themeColor,
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: _themeColor.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No upcoming events',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for updates',
              style: TextStyle(color: subtitleColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _themeColor,
      onRefresh: () => _fetchEvents(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 32, left: 16, right: 16),
        itemCount: _events.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _events.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: _themeColor),
              ),
            );
          }

          final event = _events[index];
          return _buildEventCard(context, event, cardColor, textColor, subtitleColor, isDark);
        },
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> event, Color cardColor, Color textColor, Color subtitleColor, bool isDark) {
    final title = event['title'] ?? 'Untitled Event';
    final subTitle = event['sub_title'] ?? '';
    final venue = event['venue'] ?? '';
    final dateOn = event['date_on'] ?? '';
    final author = event['author'] ?? 'Admin';
    final coverImage = event['cover_image'] ?? '';
    final hasImage = coverImage.toString().isNotEmpty;

    // Premium styling variables
    final baseBgColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final gradientEndColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100;
    final shadowColor = isDark ? Colors.black.withOpacity(0.8) : Colors.black.withOpacity(0.06);
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : _themeColor.withOpacity(0.2);

    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 4, right: 4),
      decoration: BoxDecoration(
        color: baseBgColor,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? _themeColor.withOpacity(0.15) : _themeColor.withOpacity(0.06),
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventDetailsScreen(event: event),
              ),
            );
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
                        _themeColor.withOpacity(isDark ? 0.25 : 0.1),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover Image if exists
                  if (hasImage)
                    Stack(
                      children: [
                        Image.network(
                          coverImage,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.indigo.shade400, Colors.deepPurple.shade800],
                              ),
                            ),
                            child: const Icon(Icons.stars_rounded, color: Colors.white30, size: 60),
                          ),
                        ),
                        // Date badge on image
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  dateOn.toString().split(' ').take(2).join(' '), // Short date
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date without Image badge
                        if (!hasImage)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _themeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              dateOn,
                              style: TextStyle(
                                color: isDark ? Colors.white.withOpacity(0.9) : _themeColor.withAlpha(220),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),

                        // Title
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            height: 1.2,
                          ),
                        ),
                        
                        if (subTitle.toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              subTitle,
                              style: TextStyle(
                                fontSize: 15,
                                color: subtitleColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          
                        const SizedBox(height: 16),
                        
                        // Venue
                        if (venue.toString().isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.location_on, size: 16, color: _themeColor.withOpacity(0.8)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  venue,
                                  style: TextStyle(fontSize: 13, color: subtitleColor, fontWeight: FontWeight.w500),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          
                        const SizedBox(height: 16),
                        
                        // Footer (Author)
                        Container(
                          padding: const EdgeInsets.only(top: 16),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: _themeColor.withOpacity(0.2),
                                child: Icon(Icons.person, size: 14, color: _themeColor),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Posted by $author',
                                style: TextStyle(
                                  fontSize: 12, 
                                  fontStyle: FontStyle.italic, 
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w600,
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
            ],
          ),
        ),
      ),
    );
  }
}
