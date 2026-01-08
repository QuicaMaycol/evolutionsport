import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player.dart';
import '../widgets/player_list.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Player>> _playersFuture;
  late Future<String> _userRoleFuture;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _playersFuture = _loadPlayers();
    _userRoleFuture = _getUserRole();
  }

  Future<String> _getUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return 'coach';
    
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      return response['role'] as String? ?? 'coach';
    } catch (e) {
      return 'coach'; // Default to safe role on error
    }
  }

  Future<List<Player>> _loadPlayers() async {
    final response = await Supabase.instance.client
        .from('players')
        .select(
          'id, first_name, last_name, position, sessions_completed, last_attendance',
        )
        .order('last_attendance', ascending: false);
    return (response as List)
        .map((row) => Player.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> _refreshPlayers() async {
    setState(() {
      _playersFuture = _loadPlayers();
    });
    await _playersFuture;
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _DashboardContent(
        playersFuture: _playersFuture,
        onRefresh: _refreshPlayers,
        userRoleFuture: _userRoleFuture,
      ),
      PlayerList(
        playersFuture: _playersFuture,
        onRefresh: _refreshPlayers,
        showControls: true,
        userRoleFuture: _userRoleFuture,
      ),
      const _PlaceholderPage(title: 'Calendario'),
      const _PlaceholderPage(title: 'Perfil'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evolution Sport'),
        actions: [
          FutureBuilder<String>(
            future: _userRoleFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Chip(
                  label: Text(
                    snapshot.data == 'admin' ? 'ADMIN' : 'COACH',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: snapshot.data == 'admin' ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesion',
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Jugadores'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendario',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final Future<List<Player>> playersFuture;
  final Future<void> Function() onRefresh;
  final Future<String> userRoleFuture;

  const _DashboardContent({
    required this.playersFuture,
    required this.onRefresh,
    required this.userRoleFuture,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const NextEventCard(),
          const SizedBox(height: 20),
          ComplianceKpi(playersFuture: playersFuture),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pendientes de Hoy',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                ),
                Text(
                  'Confirma la asistencia del entrenamiento',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.5),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: PlayerList(
              playersFuture: playersFuture,
              onRefresh: onRefresh,
              showControls: false,
              hideMarkedToday: true,
              userRoleFuture: userRoleFuture,
            ),
          ),
        ],
      ),
    );
  }
}

class NextEventCard extends StatelessWidget {
  const NextEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?q=80&w=1200&auto=format&fit=crop',
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Proximo Evento',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Entrenamiento Sub-15',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Hoy, 18:00',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ComplianceKpi extends StatelessWidget {
  final Future<List<Player>> playersFuture;
  const ComplianceKpi({super.key, required this.playersFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Player>>(
      future: playersFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final players = snapshot.data ?? [];
        if (players.isEmpty) return const SizedBox.shrink();

        final int totalPlayers = players.length;
        // Logic:
        // Excellent: >= 25 sessions (Approaching 30)
        // Warning: 10 - 24 sessions
        // Critical: < 10 sessions
        final int excellent =
            players.where((p) => p.sessionsCompleted >= 25).length;
        final int warning =
            players
                .where(
                  (p) =>
                      p.sessionsCompleted >= 10 && p.sessionsCompleted < 25,
                )
                .length;
        final int critical =
            players.where((p) => p.sessionsCompleted < 10).length;

        final double percentage =
            totalPlayers > 0 ? excellent / totalPlayers : 0.0;

        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A), // Soft dark surface
            borderRadius: BorderRadius.circular(24.0), // Apple-style curvature
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rendimiento Global',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Asistencia Mensual',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  _TrendIcon(percentage: percentage),
                ],
              ),
              const SizedBox(height: 24),

              // Hero Content: Ring + Big Number
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _AnimatedProgressRing(percentage: percentage),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StatRow(
                          label: 'Excelente',
                          count: excellent,
                          color: const Color(0xFF4CAF50), // Apple Green
                        ),
                        const SizedBox(height: 12),
                        _StatRow(
                          label: 'En Proceso',
                          count: warning,
                          color: const Color(0xFFFF9800), // Orange
                        ),
                        const SizedBox(height: 12),
                        _StatRow(
                          label: 'Crítico',
                          count: critical,
                          color: const Color(0xFFEF5350), // Soft Red
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedProgressRing extends StatelessWidget {
  final double percentage;
  const _AnimatedProgressRing({required this.percentage});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: percentage),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, double value, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _RingPainter(
                  percentage: value,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  gradientColors: [
                    const Color(0xFF4CAF50),
                    const Color(0xFF81C784),
                  ],
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(value * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w300, // Thin styling
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Completado',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percentage;
  final Color backgroundColor;
  final List<Color> gradientColors;

  _RingPainter({
    required this.percentage,
    required this.backgroundColor,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    final strokeWidth = 12.0;

    // Background Circle
    final bgPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress Arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: -1.5708, // -90 degrees (top)
      endAngle: 3.14 * 2 - 1.5708,
      colors: gradientColors,
      stops: [0.0, percentage],
      tileMode: TileMode.repeated,
    );

    final progressPaint =
        Paint()
          ..shader =
              percentage > 0
                  ? gradient.createShader(rect)
                  : null // Handle 0% gracefully
          ..color = gradientColors.first // Fallback
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    // Draw arc starting from top (-90 degrees)
    canvas.drawArc(
      rect,
      -1.5708, // Start at 12 o'clock
      2 * 3.14 * percentage,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _StatRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatRow({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ),
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _TrendIcon extends StatelessWidget {
  final double percentage;
  const _TrendIcon({required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            percentage >= 0.8 ? Icons.trending_up : Icons.trending_flat,
            size: 16,
            color: percentage >= 0.8 ? const Color(0xFF4CAF50) : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            percentage >= 0.8 ? 'Alto' : 'Normal',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color:
                  percentage >= 0.8 ? const Color(0xFF4CAF50) : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title (en construcción)',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}
