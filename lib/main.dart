import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Importar
import 'auth/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/super_admin_dashboard.dart';
import 'screens/subscription_locked_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mqsupabase.dashbportal.com',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ewogICJyb2xlIjogImFub24iLAogICJpc3MiOiAic3VwYWJhc2UiLAogICJpYXQiOiAxNzE1MDUwODAwLAogICJleHAiOiAxODcyODE3MjAwCn0.S-mnBPn8_f2XuK1ufFMH0OwP4Fr3DJ0aExhEye9Xp_8',
    postgrestOptions: const PostgrestClientOptions(
      schema: 'evolutionsport',
    ),
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Direction Futbol Pro',
      debugShowCheckedModeBanner: false,
      // Configuración de localización
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español como principal
        Locale('en', 'US'),
      ],
      // Forzar español o usar el del sistema si es compatible
      locale: const Locale('es', 'ES'), 
      
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF4CAF50),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardColor: const Color(0xFF2D2D2D),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF2D2D2D),
          selectedItemColor: Color(0xFF4CAF50),
          unselectedItemColor: Colors.white70,
          showUnselectedLabels: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          headlineSmall:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleLarge:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
      ),
      home: const AuthHandler(),
    );
  }
}

class AuthHandler extends StatefulWidget {
  const AuthHandler({super.key});

  @override
  State<AuthHandler> createState() => _AuthHandlerState();
}

class _AuthHandlerState extends State<AuthHandler> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final session = snapshot.data?.session;
        if (session != null) {
          return FutureBuilder<Map<String, dynamic>>(
            future: _getUserStatus(session.user.id),
            builder: (context, statusSnapshot) {
              if (statusSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }

              if (statusSnapshot.hasError) {
                // Si falla, es mejor mandarlos al login por seguridad
                return const LoginScreen();
              }

              final data = statusSnapshot.data;
              final role = data?['role'];
              final isActive = data?['is_active'] ?? true;

              if (role == 'super_admin') {
                return const SuperAdminDashboard();
              }

              if (!isActive) {
                return const SubscriptionLockedScreen();
              }

              return const DashboardScreen();
            },
          );
        }
        return const LoginScreen();
      },
    );
  }

  Future<Map<String, dynamic>> _createProfileFromMetadata(String userId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return {'role': 'unknown', 'is_active': false};

      final meta = user.userMetadata ?? {};
      final fullName = meta['full_name'] ?? 'Usuario Nuevo';
      final academyName = meta['academy_name'] ?? 'Mi Academia';
      final isFreelancer = meta['is_freelancer'] ?? false;

      String? academyId;

      // 1. Crear Perfil primero (en el esquema evolutionsport)
      try {
        await supabase.schema('evolutionsport').from('profiles').insert({
          'id': userId,
          'full_name': fullName,
          'role': 'admin',
          'is_freelancer': isFreelancer,
        });
      } catch (e) {
        debugPrint('Error creando perfil: $e');
      }

      // 2. Crear Academia
      if (!isFreelancer) {
        try {
          final newAcademy = await supabase.schema('evolutionsport').from('academies').insert({
            'name': academyName,
          }).select().single();
          
          academyId = newAcademy['id'];

          // 3. Vincular
          await supabase.schema('evolutionsport').from('profiles').update({
            'academy_id': academyId,
          }).eq('id', userId);

          await supabase.schema('evolutionsport').from('coach_academies').insert({
            'coach_id': userId,
            'academy_id': academyId,
            'role': 'admin',
            'is_active': true,
          });
        } catch (e) {
          debugPrint('Error creando academia/vínculo: $e');
        }
      }

      return {'role': 'admin', 'is_active': true};
    } catch (e) {
      debugPrint('Error general: $e');
      return {'role': 'admin', 'is_active': true};
    }
  }

  Future<Map<String, dynamic>> _getUserStatus(String userId) async {
    try {
      final response = await supabase
          .schema('evolutionsport')
          .from('profiles')
          .select('role, academy_id')
          .eq('id', userId);
      
      if (response == null || (response as List).isEmpty) {
        debugPrint('Perfil no encontrado. Iniciando auto-creación para: $userId');
        return await _createProfileFromMetadata(userId);
      }

      final profile = (response as List).first;
      final role = profile['role'];
      
      // Si es super_admin, no necesitamos verificar academia
      if (role == 'super_admin') {
        return {'role': role, 'is_active': true};
      }

      // Verificar estado de la academia
      final academyId = profile['academy_id'];
      if (academyId != null) {
        try {
          final academy = await supabase
              .schema('evolutionsport')
              .from('academies')
              .select('is_active')
              .eq('id', academyId)
              .single();
          
          // Si el campo es nulo, asumimos activo
          return {'role': role, 'is_active': academy['is_active'] ?? true};
        } catch (academyError) {
          debugPrint('Error al verificar academia: $academyError');
          // Si falla la consulta a la academia (ej: columna no existe o RLS), 
          // permitimos el acceso por defecto
          return {'role': role, 'is_active': true};
        }
      }
      
      // Fallback si algo está raro (por ejemplo, perfil recién creado)
      return {'role': role, 'is_active': true};
    } catch (e) {
      debugPrint('Error en _getUserStatus: $e');
      // En caso de error, permitimos el acceso por defecto para evitar bloqueos por RLS o latencia
      return {'role': 'unknown', 'is_active': true};
    }
  }
}
