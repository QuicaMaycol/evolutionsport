import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class DrillDetailScreen extends StatefulWidget {
  final Map<String, dynamic> drill;
  final String videoId;

  const DrillDetailScreen({
    super.key,
    required this.drill,
    required this.videoId,
  });

  @override
  State<DrillDetailScreen> createState() => _DrillDetailScreenState();
}

class _DrillDetailScreenState extends State<DrillDetailScreen> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: false,
        isLive: false,
        forceHD: false,
      ),
    )..addListener(_listener);
  }

  void _listener() {
    if (mounted && !_controller.value.isFullScreen) {
      // setState(() {});
    }
  }

  @override
  void deactivate() {
    _controller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.drill['title'],
          style: const TextStyle(color: Colors.white, fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Área del Reproductor
            Container(
              width: double.infinity,
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(
                  controller: _controller,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: const Color(0xFF4CAF50),
                  onReady: () {
                    _isPlayerReady = true;
                  },
                  bottomActions: [
                    CurrentPosition(),
                    ProgressBar(isExpanded: true),
                    RemainingDuration(),
                    const PlaybackSpeedButton(),
                  ],
                ),
              ),
            ),

            // 2. Información del Ejercicio
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Etiquetas / Categoría
                  Row(
                    children: [
                      _buildTag(widget.drill['category'] ?? 'main'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.people, size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.drill['min_players']}+ Jugadores',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Título Grande
                  Text(
                    widget.drill['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Descripción
                  const Text(
                    'DESCRIPCIÓN',
                    style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.drill['description'] ?? 'Sin descripción disponible.',
                    style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // Materiales
                  if (widget.drill['materials'] != null && (widget.drill['materials'] as List).isNotEmpty) ...[
                    const Text(
                      'MATERIALES',
                      style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (widget.drill['materials'] as List).map((m) {
                        return Chip(
                          backgroundColor: Colors.white.withOpacity(0.05),
                          label: Text(m.toString(), style: const TextStyle(color: Colors.white)),
                          avatar: const Icon(Icons.sports_soccer, size: 14, color: Colors.white54),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String category) {
    Color color;
    String label;
    switch (category) {
      case 'warmup':
        color = Colors.amber;
        label = 'Activación';
        break;
      case 'cooldown':
        color = Colors.greenAccent;
        label = 'Vuelta a la Calma';
        break;
      default:
        color = const Color(0xFF4CAF50);
        label = 'Fase Principal';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
