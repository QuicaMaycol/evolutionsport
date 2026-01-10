import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player.dart';
import '../widgets/player_list.dart';
import 'team_management_screen.dart';
import 'groups_screen.dart';
import 'calendar_screen.dart';
import 'coach_profile_screen.dart';
import 'template_library_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Player>> _playersFuture;
  late Future<Map<String, dynamic>> _profileDataFuture;
  late Future<List<Map<String, dynamic>>> _myAcademiesFuture;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _playersFuture = _loadPlayers();
    _profileDataFuture = _getProfileData();
    _myAcademiesFuture = _loadMyAcademies();
  }

  Future<List<Map<String, dynamic>>> _loadMyAcademies() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await Supabase.instance.client
          .from('coach_academies')
          .select('academy_id, academies(name)')
          .eq('coach_id', user.id)
          .eq('is_active', true);
      
      return List<Map<String, dynamic>>.from(response.map((e) => {
        'id': e['academy_id'],
        'name': e['academies']['name'],
      }));
    } catch (e) {
      return [];
    }
  }

  Future<void> _switchAcademy(String? newAcademyId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'academy_id': newAcademyId})
          .eq('id', user.id);
      
      setState(() {
        _profileDataFuture = _getProfileData();
        _playersFuture = _loadPlayers();
        _selectedIndex = 0;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cambiando de club: $e')));
    }
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
      if (academyId == null) return [];

      final response = await Supabase.instance.client
          .from('players')
          .select('id, first_name, last_name, position, sessions_completed, last_attendance')
          .eq('academy_id', academyId)
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
        
        // Lógica clave: Mostrar vista freelancer SOLO si no hay academia seleccionada
        final isViewFreelance = academyId == null;

        final pages = <Widget>[
          if (isViewFreelance)
            _FreelanceDashboard(
              onNavigateToStore: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TemplateLibraryScreen()),
                );
              },
            )
          else
            _DashboardContent(
              playersFuture: _playersFuture,
              onRefresh: _refreshPlayers,
              userRoleFuture: Future.value(role),
            ),
          
          if (!isViewFreelance)
            PlayerList(
              playersFuture: _playersFuture,
              onRefresh: _refreshPlayers,
              showControls: true,
              userRoleFuture: Future.value(role),
            )
          else
            const CoachProfileScreen(),
          
          if (!isViewFreelance)
            const GroupsScreen(),
          const CalendarScreen(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: FutureBuilder<List<Map<String, dynamic>>>(
              future: _myAcademiesFuture,
              builder: (context, academiesSnapshot) {
                if (!academiesSnapshot.hasData || academiesSnapshot.data!.isEmpty) {
                   return const Text('Evolution Sport');
                }

                final myAcademies = academiesSnapshot.data!;
                final allOptions = [
                  if (role == 'coach') {'id': null, 'name': 'Modo Freelancer'},
                  ...myAcademies
                ];

                if (allOptions.length <= 1) {
                  return Text(
                    allOptions.isNotEmpty ? (allOptions[0]['name'] ?? 'Evolution Sport') : 'Evolution Sport',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  );
                }

                return DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: academyId,
                    dropdownColor: Theme.of(context).primaryColor,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    items: allOptions.map((academy) {
                      return DropdownMenuItem<String?>(
                        value: academy['id'] as String?,
                        child: Text(
                          academy['name'] ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != academyId) {
                        _switchAcademy(newValue);
                      }
                    },
                  ),
                );
              },
            ),
            actions: [
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
                    role == 'admin' ? 'ADMIN' : (isViewFreelance ? 'FREELANCE' : 'COACH'),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: role == 'admin' ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
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
                icon: Icon(isViewFreelance ? Icons.person : Icons.people), 
                label: isViewFreelance ? 'Mi Perfil' : 'Jugadores'
              ),
              if (!isViewFreelance)
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
    bool isProcessing = false;
    String? errorMessage;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Unirse a un Club'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ingresa el código que te proporcionó el administrador de la academia.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: 'Código de Academia',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.vpn_key),
                      errorText: errorMessage,
                    ),
                    enabled: !isProcessing,
                  ),
                  if (isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                if (!isProcessing)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                if (!isProcessing)
                  ElevatedButton(
                    onPressed: () async {
                      final code = codeController.text.trim();
                      if (code.isEmpty) return;
                      
                      setState(() {
                        isProcessing = true;
                        errorMessage = null;
                      });
                      
                      try {
                        // 1. Validar código con RPC seguro
                        final validation = await Supabase.instance.client
                            .rpc('validate_academy_code', params: {'code_input': code});
                        
                        final isValid = validation['valid'] as bool;
                        
                        if (!isValid) {
                          setState(() {
                            isProcessing = false;
                            errorMessage = 'Código incorrecto. Academia no encontrada.';
                          });
                          return;
                        }
                        
                        final academyName = validation['name'] as String;

                        // 2. Insertar membresía
                        final userId = Supabase.instance.client.auth.currentUser!.id;
                        await Supabase.instance.client.from('coach_academies').insert({
                          'coach_id': userId,
                          'academy_id': code,
                          'role': 'coach',
                          'is_active': true
                        });

                        // 3. Cambiar contexto
                        await Supabase.instance.client.from('profiles').update({
                          'academy_id': code,
                        }).eq('id', userId);

                        if (context.mounted) {
                          Navigator.pop(context); // Cerrar diálogo
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('¡Te has unido a $academyName!')),
                          );
                          // Recargar dashboard completo
                          Navigator.pushReplacement(
                            context, 
                            MaterialPageRoute(builder: (_) => const DashboardScreen())
                          );
                        }

                      } catch (e) {
                         final errorMsg = e.toString();
                         debugPrint('Error al unirse: $errorMsg');

                         setState(() {
                           isProcessing = false;
                           if (errorMsg.contains('23505') || errorMsg.contains('duplicate key')) {
                             errorMessage = '¡Ya eres miembro de esta academia!';
                             // Intento de auto-corrección de contexto
                             try {
                                final userId = Supabase.instance.client.auth.currentUser!.id;
                                Supabase.instance.client.from('profiles').update({'academy_id': code}).eq('id', userId);
                                Future.delayed(Duration.zero, () {
                                  Navigator.pop(context);
                                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
                                });
                             } catch (_) {}
                           } else {
                             errorMessage = 'Error: $e';
                           }
                         });
                      }
                    },
                    child: const Text('Unirse'),
                  ),
              ],
            );
          },
        );
      },
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
