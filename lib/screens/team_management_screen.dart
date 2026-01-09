import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  String? _academyCode;
  List<Map<String, dynamic>> _coaches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Get Academy ID (The Code)
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('academy_id')
          .eq('id', user.id)
          .single();
      
      final academyId = profileResponse['academy_id'] as String;

      // 2. Get Coaches
      final coachesResponse = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, created_at')
          .eq('academy_id', academyId)
          .eq('role', 'coach'); // Only fetch coaches, not other admins

      if (mounted) {
        setState(() {
          _academyCode = academyId;
          _coaches = List<Map<String, dynamic>>.from(coachesResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando datos: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeCoach(String coachId, String coachName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Entrenador'),
        content: Text('¿Estás seguro de que quieres eliminar a $coachName? Perderá el acceso inmediatamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Option A: Just delete profile (User remains but has no data/access)
        // Option B: Call Edge Function to delete auth user (Best)
        // Since we are client-side only for now, we will delete the profile link.
        // Or better: update role to 'inactive' if we had that status.
        // For now, let's DELETE the profile row. The auth user will remain but 'ghosted'.
        
        await Supabase.instance.client.from('profiles').delete().eq('id', coachId);
        
        // Refresh list
        _loadTeamData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('$coachName ha sido eliminado.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  void _copyCode() {
    if (_academyCode != null) {
      Clipboard.setData(ClipboardData(text: _academyCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código copiado al portapapeles'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipo Técnico')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InviteCard(code: _academyCode, onCopy: _copyCode),
                const SizedBox(height: 32),
                Text(
                  'Entrenadores Activos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (_coaches.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.sports_soccer, size: 48, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'Aún no hay entrenadores',
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  )
                else
                  ..._coaches.map((coach) => _CoachTile(
                        name: coach['full_name'] ?? 'Sin nombre',
                        joinedAt: coach['created_at'] != null 
                            ? DateTime.parse(coach['created_at']).toLocal().toString().split(' ')[0]
                            : '-',
                        onDelete: () => _removeCoach(coach['id'], coach['full_name'] ?? 'Entrenador'),
                      )),
              ],
            ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final String? code;
  final VoidCallback onCopy;

  const _InviteCard({required this.code, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF1F1F1F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          const Icon(Icons.qr_code_2, size: 48, color: Color(0xFF4CAF50)),
          const SizedBox(height: 16),
          const Text(
            'Invitar Entrenador',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comparte este código para que se unan a tu academia.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code ?? 'Cargando...',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.copy, size: 18, color: Color(0xFF4CAF50)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachTile extends StatelessWidget {
  final String name;
  final String joinedAt;
  final VoidCallback onDelete;

  const _CoachTile({
    required this.name,
    required this.joinedAt,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blueGrey.shade800,
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Unido: $joinedAt', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
