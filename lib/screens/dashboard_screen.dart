import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player.dart';
import '../widgets/player_list.dart';
import 'team_management_screen.dart';
import 'groups_screen.dart';
import 'calendar_screen.dart';
import 'coach_profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Player>> _playersFuture;
  late Future<Map<String, dynamic>> _profileDataFuture;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _playersFuture = _loadPlayers();
    _profileDataFuture = _getProfileData();
  }

  Future<Map<String, dynamic>> _getProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return {'role': 'coach', 'academy_id': null, 'is_freelancer': false};
    
    final response = await Supabase.instance.client
        .from('profiles')
        .select('role, academy_id, is_freelancer')
        .eq('id', user.id)
        .single();
    return Map<String, dynamic>.from(response);
  }

  Future<List<Player>> _loadPlayers() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('academy_id')
          .eq('id', user.id)
          .single();
      
      final academyId = profile['academy_id'];
      if (academyId == null) return []; // Si es Freelance, lista vacía garantizada

      // FILTRO ESTRICTO: Solo jugadores de MI academia
      final response = await Supabase.instance.client
          .from('players')
          .select('id, first_name, last_name, position, sessions_completed, last_attendance')
          .eq('academy_id', academyId) // <--- CRUCIAL: Seguridad añadida
          .order('last_attendance', ascending: false);
      
      return (response as List)
          .map((row) => Player.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _refreshPlayers() async {
    setState(() {
      _playersFuture = _loadPlayers();
    });
    await _playersFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileDataFuture,
      builder: (context, profileSnapshot) {
        if (!profileSnapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        final role = profileSnapshot.data!['role'];
        final academyId = profileSnapshot.data!['academy_id'];
        // Ahora se considera Freelancer si:
        // 1. Tiene el flag 'is_freelancer' en TRUE en la base de datos
        // 2. O, como respaldo, si no tiene academia asignada (antiguo comportamiento)
        final isFreelancerFlag = profileSnapshot.data!['is_freelancer'] == true;
        final isFreelance = isFreelancerFlag || academyId == null;

        final pages = <Widget>[
          if (isFreelance)
            _FreelanceDashboard(onNavigateToStore: () => setState(() => _selectedIndex = 1))
          else
            _DashboardContent(
              playersFuture: _playersFuture,
              onRefresh: _refreshPlayers,
              userRoleFuture: Future.value(role),
            ),
          
          if (!isFreelance)
            PlayerList(
              playersFuture: _playersFuture,
              onRefresh: _refreshPlayers,
              showControls: true,
              userRoleFuture: Future.value(role),
            )
          else
            const CoachProfileScreen(),
          
          const GroupsScreen(),
          const CalendarScreen(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Evolution Sport'),
            actions: [
              FutureBuilder<Map<String, dynamic>>(
                future: _profileDataFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final role = snapshot.data!['role'];
                  return Row(
                    children: [
                      if (role == 'admin')
                        IconButton(
                          icon: const Icon(Icons.people_outline),
                          tooltip: 'Gestionar Equipo',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const TeamManagementScreen()),
                            );
                          },
                        ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Chip(
                          label: Text(
                            role == 'admin' ? 'ADMIN' : (isFreelance ? 'FREELANCE' : 'COACH'),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: role == 'admin' ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => Supabase.instance.client.auth.signOut(),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: pages[_selectedIndex % pages.length],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            items: [
              const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Inicio'),
              BottomNavigationBarItem(
                icon: Icon(isFreelance ? Icons.person : Icons.people), 
                label: isFreelance ? 'Mi Perfil' : 'Jugadores'
              ),
              const BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Grupos'),
              const BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Planificar'),
            ],
          ),
        );
      },
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
          const Text('Pendientes de Hoy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 400,
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

class _FreelanceDashboard extends StatelessWidget {
  final VoidCallback onNavigateToStore;
  const _FreelanceDashboard({required this.onNavigateToStore});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text('Bienvenido, Profe', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Construye tu marca personal y vende tu conocimiento.', style: TextStyle(color: Colors.white38)),
        const SizedBox(height: 32),
        _buildActionCard(context, title: 'Mi Biblioteca Táctica', desc: 'Gestiona y publica tus microciclos.', icon: Icons.library_books, color: Colors.amber, onTap: onNavigateToStore),
        const SizedBox(height: 16),
        _buildActionCard(
          context, 
          title: 'Unirse a un Club', 
          desc: 'Ingresa el código de tu nueva academia.', 
          icon: Icons.add_business, 
          color: Colors.blue, 
          onTap: () {
            _showJoinAcademyDialog(context);
          }
        ),
      ],
    );
  }

  void _showJoinAcademyDialog(BuildContext context) {
    final codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unirse a un Club'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingresa el código que te proporcionó el administrador de la academia.'),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Código de Academia',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              
              Navigator.pop(context); // Cierra dialogo
              
              try {
                // 1. Validar que la academia existe
                final academy = await Supabase.instance.client
                    .from('academies')
                    .select()
                    .eq('id', code) // Asumimos que el código ES el ID
                    .maybeSingle();
                
                if (academy == null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Código de academia inválido o no encontrado.'), backgroundColor: Colors.red),
                    );
                  }
                  return;
                }

                // 2. Actualizar el perfil del usuario para asignarle la academia
                // Mantenemos is_freelancer en true porque sigue siendo freelancer aunque se una
                final userId = Supabase.instance.client.auth.currentUser!.id;
                await Supabase.instance.client.from('profiles').update({
                  'academy_id': code,
                  // Opcional: ¿is_freelancer se mantiene en true? 
                  // El usuario dijo: "manteniedo sus plantillas y de mas cierto?"
                  // Asi que sí, se mantiene como freelancer pero vinculado a una academia.
                }).eq('id', userId);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('¡Te has unido a ${academy['name']}!')),
                  );
                  // Recargar la app o el dashboard para reflejar cambios
                  // Lo más simple es trigger un rebuild del dashboard padre si fuera posible,
                  // pero como esto es un StatelessWidget, pedimos al usuario recargar o hacemos un pushReplacement
                  // Para efectos prácticos, navegar al Dashboard forzará un rebuild
                  Navigator.pushReplacement(
                    context, 
                    MaterialPageRoute(builder: (_) => const DashboardScreen())
                  );
                }

              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al unirse: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Unirse'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String title, required String desc, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: const Color(0xFF2D2D2D), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(desc, style: const TextStyle(color: Colors.white38, fontSize: 13))])),
          ],
        ),
      ),
    );
  }
}

// Re-incluir ComplianceKpi y otros widgets auxiliares necesarios para Dashboard
class NextEventCard extends StatelessWidget {
  const NextEventCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(height: 150, color: Colors.blueGrey, child: const Center(child: Text('Próximo Entrenamiento'))),
    );
  }
}

class ComplianceKpi extends StatelessWidget {
  final Future<List<Player>> playersFuture;
  const ComplianceKpi({super.key, required this.playersFuture});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(20)), child: const Text('Rendimiento Global: 85%'));
  }
}
