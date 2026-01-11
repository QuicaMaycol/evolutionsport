import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/player.dart';
import '../widgets/player_list.dart';
import 'team_management_screen.dart';
import 'groups_screen.dart';
import 'calendar_screen.dart';
import 'coach_profile_screen.dart';
import 'template_library_screen.dart';
import 'drills_library_screen.dart';
import 'player_evaluation_screen.dart';

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
    if (user == null) return {'role': 'coach', 'academy_id': null, 'is_freelancer': false, 'full_name': 'Entrenador'};
    
    final response = await Supabase.instance.client
        .from('profiles')
        .select('full_name, role, academy_id, is_freelancer')
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
        final fullName = profileSnapshot.data!['full_name'] ?? 'Profe';
        
        // Lógica clave: Mostrar vista freelancer SOLO si no hay academia seleccionada
        final isViewFreelance = academyId == null;

        final pages = <Widget>[
          if (isViewFreelance)
            _FreelanceDashboard(
              fullName: fullName,
              onNavigateToStore: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TemplateLibraryScreen()),
                );
              },
            )
          else
            _DashboardContent(
              fullName: fullName,
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
                
                // Si es ADMIN, no mostramos "Modo Freelancer"
                // El admin está atado a su gestión.
                // Si es COACH, le damos la libertad.
                final isCoach = role == 'coach';
                
                final allOptions = [
                  if (isCoach) {'id': null, 'name': 'Modo Freelancer'},
                  ...myAcademies
                ];
                
                // Si solo hay una opción (ej: Admin con su academia), mostramos texto fijo, no dropdown
                if (allOptions.length <= 1) {
                   // Si es Admin, mostramos el nombre de su academia actual
                   // Buscamos el nombre en la lista myAcademies que coincida con academyId
                   var currentAcademyName = 'Evolution Sport';
                   if (academyId != null && myAcademies.isNotEmpty) {
                      final found = myAcademies.firstWhere(
                        (a) => a['id'] == academyId, 
                        orElse: () => {'name': null}
                      );
                      if (found['name'] != null) {
                        currentAcademyName = found['name'];
                      }
                   }
                   
                   return Text(currentAcademyName, style: const TextStyle(fontWeight: FontWeight.bold));
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
  final String fullName;
  final Future<List<Player>> playersFuture;
  final Future<void> Function() onRefresh;
  final Future<String> userRoleFuture;

  const _DashboardContent({
    required this.fullName,
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
          _WelcomeHeader(fullName: fullName),
          const SizedBox(height: 24),
          _ActivityRings(),
          const SizedBox(height: 24),
          SmartStatusCard(playersFuture: playersFuture),
          const SizedBox(height: 24),
          const Text('Herramientas Técnicas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  title: 'Evaluar Desempeño',
                  icon: Icons.analytics,
                  color: const Color(0xFF64B5F6),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PlayerEvaluationScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _QuickActionCard(
                  title: 'Banco de Ejercicios',
                  icon: Icons.fitness_center,
                  color: const Color(0xFF4CAF50),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const DrillsLibraryScreen()));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _QuickActionCard(
            title: 'Biblioteca Táctica',
            icon: Icons.library_books,
            color: const Color(0xFFFFC107),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TemplateLibraryScreen()));
            },
          ),
          const SizedBox(height: 32),
          const Text('Pendientes de Hoy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 16),
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

class _WelcomeHeader extends StatelessWidget {
  final String fullName;
  const _WelcomeHeader({required this.fullName});

  @override
  Widget build(BuildContext context) {
    final firstName = fullName.split(' ')[0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hola, $firstName 👋',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        const SizedBox(height: 4),
        Text(
          'Tu academia está lista para la acción hoy.',
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)),
        ),
      ],
    );
  }
}

class _ActivityRings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _RingItem(label: 'Asistencia', value: '85%', color: Colors.green),
          _RingItem(label: 'Progreso', value: '60%', color: Colors.blue),
          _RingItem(label: 'Carga RPE', value: '7.2', color: Colors.orange),
        ],
      ),
    );
  }
}

class _RingItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _RingItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: 0.7, // Placeholder logic
                strokeWidth: 6,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeCap: StrokeCap.round,
              ),
            ),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
      ],
    );
  }
}


class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreelanceDashboard extends StatelessWidget {
  final String fullName;
  final VoidCallback onNavigateToStore;
  const _FreelanceDashboard({required this.fullName, required this.onNavigateToStore});

  @override
  Widget build(BuildContext context) {
    final firstName = fullName.split(' ')[0];
    return ListView(
      children: [
        _WelcomeHeader(fullName: fullName),
        const SizedBox(height: 32),
        _buildActionCard(context, title: 'Mi Biblioteca Táctica', desc: 'Gestiona y publica tus microciclos.', icon: Icons.library_books, color: Colors.amber, onTap: onNavigateToStore),
        const SizedBox(height: 16),
        _buildActionCard(
          context, 
          title: 'Banco de Ejercicios', 
          desc: 'Tus tareas y ejercicios de entrenamiento.', 
          icon: Icons.fitness_center, 
          color: Colors.green, 
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const DrillsLibraryScreen()));
          }
        ),
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

class SmartStatusCard extends StatelessWidget {
  final Future<List<Player>> playersFuture;

  const SmartStatusCard({super.key, required this.playersFuture});

  Future<Map<String, dynamic>> _getDashboardData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return {};

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('academy_id')
        .eq('id', user.id)
        .single();
    
    final academyId = profile['academy_id'];

    // 1. Calcular Carga RPE Semanal
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final eventsResp = await Supabase.instance.client
        .from('events')
        .select('rpe')
        .eq('academy_id', academyId)
        .gte('start_time', startOfWeek.toIso8601String())
        .lte('start_time', endOfWeek.toIso8601String());

    double avgRpe = 0;
    if (eventsResp.isNotEmpty) {
      final totalRpe = (eventsResp as List).fold<int>(0, (sum, item) => sum + (item['rpe'] as int? ?? 0));
      avgRpe = totalRpe / eventsResp.length;
    }

    return {
      'avgRpe': avgRpe,
      'eventsCount': eventsResp.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Player>>(
      future: playersFuture,
      builder: (context, playersSnapshot) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _getDashboardData(),
          builder: (context, dataSnapshot) {
            final players = playersSnapshot.data ?? [];
            final data = dataSnapshot.data ?? {'avgRpe': 0.0, 'eventsCount': 0};

            // Lógica de Alertas
            final today = DateTime.now();
            final birthdays = players.where((p) => p.birthDate != null && p.birthDate!.day == today.day && p.birthDate!.month == today.month).toList();

            final avgRpe = data['avgRpe'] as double;
            final intensityColor = avgRpe >= 7 ? Colors.redAccent : (avgRpe >= 4 ? Colors.orangeAccent : Colors.blueAccent);

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Sección Alertas (Izquierda)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Alertas de Hoy',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1),
                          ),
                          const SizedBox(height: 16),
                          if (birthdays.isEmpty)
                            const Text('Todo bajo control ✨', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          
                          if (birthdays.isNotEmpty)
                            _StatusItem(
                              icon: Icons.cake,
                              color: Colors.pinkAccent,
                              text: 'Cumple de ${birthdays.first.firstName}',
                            ),
                        ],
                      ),
                    ),
                    
                    VerticalDivider(color: Colors.white.withOpacity(0.1), thickness: 1, indent: 8, endIndent: 8),
                    
                    // Sección Pulso/RPE (Derecha)
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'PULSO SEMANAL',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white24),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            avgRpe.toStringAsFixed(1),
                            style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: intensityColor, letterSpacing: -2),
                          ),
                          Text(
                            avgRpe >= 7 ? 'Carga Alta' : (avgRpe >= 4 ? 'Óptimo' : 'Recuperación'),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: intensityColor.withOpacity(0.8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _StatusItem({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              overflow: TextOverflow.ellipsis,
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
    return const SizedBox.shrink(); // Obsoleto, reemplazado por SmartStatusCard
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
