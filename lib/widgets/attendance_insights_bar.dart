import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/attendance_report_screen.dart';
import '../screens/attendance_history_screen.dart';
import '../models/player.dart';

class AttendanceInsightsBar extends StatefulWidget {
  final List<Player> allPlayers;
  const AttendanceInsightsBar({super.key, required this.allPlayers});

  @override
  State<AttendanceInsightsBar> createState() => _AttendanceInsightsBarState();
}

class _AttendanceInsightsBarState extends State<AttendanceInsightsBar> {
  int _absentYesterday = 0;
  String _commitmentRate = "0%";
  int _atRiskCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  @override
  void didUpdateWidget(AttendanceInsightsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.allPlayers != oldWidget.allPlayers) {
      _loadInsights();
    }
  }

  Future<void> _loadInsights() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('profiles').select('academy_id').eq('id', user!.id).single();
      final academyId = profile['academy_id'];

      if (academyId == null) return;

      final lastSession = await Supabase.instance.client
          .from('sessions')
          .select('id')
          .eq('academy_id', academyId)
          .order('date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastSession != null) {
        final attendance = await Supabase.instance.client
            .from('session_attendance')
            .select()
            .eq('session_id', lastSession['id'])
            .eq('is_present', false);
        
        if (mounted) {
          setState(() {
            _absentYesterday = (attendance as List).length;
          });
        }
      }

      if (mounted) {
        setState(() {
          _commitmentRate = "94%"; 
          _atRiskCount = _absentYesterday > 2 ? 1 : 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));

    return Column(
      children: [
        // Fila 1: Tarjetas de Resumen
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildReportCard('Ausentes Ayer', '$_absentYesterday', Icons.person_off_outlined, Colors.redAccent),
              const SizedBox(width: 12),
              _buildReportCard('Compromiso', _commitmentRate, Icons.star_outline, Colors.greenAccent),
              const SizedBox(width: 12),
              _buildReportCard('En Riesgo', '$_atRiskCount', Icons.warning_amber_outlined, Colors.amberAccent),
            ],
          ),
        ),
        
        const SizedBox(height: 12),

        // Fila 2: Botones de Acción
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _buildActionButton(
                'HISTORIAL', 
                Icons.calendar_month, 
                Colors.purpleAccent, 
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen()))
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildActionButton(
                'REPORTES', 
                Icons.bar_chart, 
                Colors.blueAccent, 
                () => Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceReportScreen(players: widget.allPlayers)))
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 120, // Reducido un poco para que quepan mejor
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Métodos antiguos eliminados para limpieza
  /* 
  Widget _buildHistoryButton() ...
  Widget _buildVerTodoCard() ...
  */


  Widget _buildActivityRings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildRing('Asistencia', 0.85, Colors.green),
          _buildRing('Progreso', 0.60, Colors.blue),
          _buildRing('Carga RPE', 0.72, Colors.orange, label: '7.2'),
        ],
      ),
    );
  }

  Widget _buildRing(String title, double percent, Color color, {String? label}) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 6,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              label ?? '${(percent * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
      ],
    );
  }
}
