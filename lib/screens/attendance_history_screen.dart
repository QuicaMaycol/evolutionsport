import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es').then((_) => _loadHistory());
  }

  Future<void> _loadHistory() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Obtener ID de la academia del usuario actual
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('academy_id')
          .eq('id', user.id)
          .single();
      
      final academyId = profile['academy_id'];
      if (academyId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Consultar sesiones con sus asistencias y nombres de jugadores
      // Usamos una consulta relacional profunda
      final response = await Supabase.instance.client
          .from('sessions')
          .select('''
            id,
            date,
            session_attendance (
              is_present,
              players (
                first_name,
                last_name,
                position
              )
            )
          ''')
          .eq('academy_id', academyId)
          .order('date', ascending: false);

      if (mounted) {
        setState(() {
          _sessions = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando historial: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Historial de Asistencias'),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(
                  child: Text(
                    'No hay registros de sesiones pasadas.',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    final date = DateTime.parse(session['date']);
                    final formattedDate = DateFormat('EEEE d, MMMM y', 'es').format(date);
                    final attendances = session['session_attendance'] as List<dynamic>;
                    
                    final presentCount = attendances.where((a) => a['is_present'] == true).length;
                    final totalCount = attendances.length;

                    return Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        collapsedIconColor: Colors.white54,
                        iconColor: Colors.blueAccent,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.calendar_today, color: Colors.blueAccent, size: 20),
                        ),
                        title: Text(
                          formattedDate.toUpperCase(), // Ej: LUNES 12, ENERO 2026
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Asistencia: $presentCount / $totalCount jugadores',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                        ),
                        children: [
                          Container(
                            color: Colors.black12,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              children: attendances.map<Widget>((att) {
                                final player = att['players'];
                                final isPresent = att['is_present'] as bool;
                                
                                if (player == null) return const SizedBox.shrink();

                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: isPresent 
                                        ? Colors.green.withOpacity(0.2) 
                                        : Colors.red.withOpacity(0.2),
                                    child: Icon(
                                      isPresent ? Icons.check : Icons.close,
                                      size: 14,
                                      color: isPresent ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  title: Text(
                                    '${player['first_name']} ${player['last_name']}',
                                    style: TextStyle(
                                      color: isPresent ? Colors.white : Colors.white54,
                                    ),
                                  ),
                                  trailing: Text(
                                    player['position'] ?? '',
                                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
