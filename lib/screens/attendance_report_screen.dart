import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player.dart';

class AttendanceReportScreen extends StatefulWidget {
  final List<Player> players;
  const AttendanceReportScreen({super.key, required this.players});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  @override
  Widget build(BuildContext context) {
    // Ordenar jugadores por asistencia (Mayor a menor)
    final sortedPlayers = List<Player>.from(widget.players)
      ..sort((a, b) => b.sessionsCompleted.compareTo(a.sessionsCompleted));

    final topPlayers = sortedPlayers.take(5).toList();
    final bottomPlayers = sortedPlayers.reversed.take(5).toList().reversed.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Reporte de Asistencia'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Top 5 - Mayor Asistencia', Icons.star, Colors.greenAccent),
            const SizedBox(height: 16),
            ...topPlayers.map((p) => _buildPlayerRow(p, Colors.greenAccent)),
            
            const SizedBox(height: 40),
            
            _buildSectionTitle('Zona de Alerta - Menor Asistencia', Icons.warning_amber_rounded, Colors.redAccent),
            const SizedBox(height: 16),
            ...bottomPlayers.map((p) => _buildPlayerRow(p, Colors.redAccent)),

            const SizedBox(height: 40),
            
            _buildSectionTitle('Resumen por Posición', Icons.pie_chart_outline, Colors.blueAccent),
            const SizedBox(height: 16),
            _buildPositionSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
      ],
    );
  }

  Widget _buildPlayerRow(Player player, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color.withOpacity(0.2),
            child: Text(player.position[0], style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(player.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          ),
          Text(
            '${player.sessionsCompleted} ses.',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionSummary() {
    final positions = ['POR', 'DEF', 'MED', 'DEL'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: positions.map((pos) {
          final playersInPos = widget.players.where((p) => p.position == pos).toList();
          if (playersInPos.isEmpty) return const SizedBox.shrink();
          
          final totalSessions = playersInPos.fold(0, (sum, p) => sum + p.sessionsCompleted);
          final avg = totalSessions / playersInPos.length;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(width: 40, child: Text(pos, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
                Expanded(
                  child: LinearProgressIndicator(
                    value: avg / 50, // Asumiendo 50 como máximo ideal para visualización
                    backgroundColor: Colors.white.withOpacity(0.05),
                    color: Colors.blueAccent.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${avg.toStringAsFixed(1)} avg', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
