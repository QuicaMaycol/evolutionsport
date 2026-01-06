
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/auth/login_screen.dart';

Future<void> main() async {
  // Asegúrate de que los widgets de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Supabase. Esta es la forma correcta y definitiva.
    await Supabase.initialize(
        url: 'https://mqsupabase.dashbportal.com',
            anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ewogICJyb2xlIjogImFub24iLAogICJpc3MiOiAic3VwYWJhc2UiLAogICJpYXQiOiAxNzE1MDUwODAwLAogICJleHAiOiAxODcyODE3MjAwCn0.S-mnBPn8_f2XuK1ufFMH0OwP4Fr3DJ0aExhEye9Xp_8',
                // Usamos PostgrestClientOptions para definir el schema por defecto para todas las consultas.
                    postgrestOptions: const PostgrestClientOptions(
                          schema: 'evolutionsport',
                              ),
                                );

  runApp(const MyApp());
}

// Obtén una instancia del cliente de Supabase para usar en tu app
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Academia de Fútbol',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF4CAF50),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardColor: const Color(0xFF2D2D2D),
        inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF2D2D2D),
          selectedItemColor: Color(0xFF4CAF50),
          unselectedItemColor: Colors.white70,
        ),
      ),
      home: const AuthHandler(),
    );
  }
}

class AuthHandler extends StatelessWidget {
  const AuthHandler({super.key});

  @override
  Widget build(BuildContext context) {
    // Escucha los cambios de estado de autenticación
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Si hay un cambio y hay una sesión, muestra el Dashboard
        if (snapshot.hasData && snapshot.data?.session != null) {
          return const DashboardScreen();
        }
        // Si no, muestra la pantalla de Login
        return const LoginScreen();
      },
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    DashboardContent(),
    Text('Jugadores'),
    Text('Calendario'),
    Text('Perfil'),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => supabase.auth.signOut(),
            tooltip: 'Cerrar Sesión',
          )
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Jugadores',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendario',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          NextEventCard(),
          SizedBox(height: 24),
          ComplianceKpi(),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?q=80&w=2970&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
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
                  'Próximo Evento',
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
                    const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Hoy, 18:00',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ComplianceKpi extends StatefulWidget {
  const ComplianceKpi({super.key});

  @override
  State<ComplianceKpi> createState() => _ComplianceKpiState();
}

class _ComplianceKpiState extends State<ComplianceKpi> {
  late Future<Map<String, dynamic>> _complianceData;

  @override
  void initState() {
    super.initState();
    _complianceData = _fetchComplianceData();
  }

  Future<Map<String, dynamic>> _fetchComplianceData() async {
    try {
      // Ya no es necesario especificar el schema aquí, porque está en la inicialización global.
      final List<Map<String, dynamic>> players = await supabase
          .from('players')
          .select('sessions_completed, total_sessions');

      if (players.isEmpty) {
        return {
          'totalPlayers': 0,
          'fulfilled': 0,
          'missing5': 0,
          'missing20': 0,
          'missing29': 0,
          'percentage': 0.0,
        };
      }

      int totalPlayers = players.length;
      int fulfilled = 0;
      int missing5 = 0;
      int missing20 = 0;
      int missing29 = 0;

      for (var player in players) {
        final completed = player['sessions_completed'] as int;
        final total = player['total_sessions'] as int;
        final missing = total - completed;

        if (missing <= 0) {
          fulfilled++;
        } else if (missing <= 5) {
          missing5++;
        } else if (missing <= 20) {
          missing20++;
        } else {
          missing29++;
        }
      }

      final double percentage = totalPlayers > 0 ? fulfilled / totalPlayers : 0.0;

      return {
        'totalPlayers': totalPlayers,
        'fulfilled': fulfilled,
        'missing5': missing5,
        'missing20': missing20,
        'missing29': missing29,
        'percentage': percentage,
      };
    } catch (e) {
      // Si hay un error, lo lanzamos para que el FutureBuilder lo capture
      throw Exception('Error al cargar los datos de cumplimiento: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _complianceData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No hay datos de jugadores.'));
            }

            final data = snapshot.data!;
            final int totalPlayers = data['totalPlayers'];
            final double percentage = data['percentage'];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KPI de Cumplimiento', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: percentage,
                                strokeWidth: 10,
                                backgroundColor: Colors.grey.shade700,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                              ),
                              Center(
                                child: Text(
                                  '${(percentage * 100).toInt()}%',
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('De $totalPlayers jugadores:', style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text('${data['fulfilled']} cumplieron'),
                          Text('${data['missing5']} faltan 5 sesiones'),
                          Text('${data['missing20']} faltan 20 sesiones'),
                          Text('${data['missing29']} faltan 29 sesiones'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
