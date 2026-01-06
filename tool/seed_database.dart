
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  print('Iniciando el proceso de siembra de datos...');

  try {
    // 1. Inicializar Supabase
    await Supabase.initialize(
      url: 'https://mqsupabase.dashbportal.com',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ewogICJyb2xlIjogImFub24iLAogICJpc3MiOiAic3VwYWJhc2UiLAogICJpYXQiOiAxNzE1MDUwODAwLAogICJleHAiOiAxODcyODE3MjAwCn0.S-mnBPn8_f2XuK1ufFMH0OwP4Fr3DJ0aExhEye9Xp_8',
      postgrestOptions: const PostgrestClientOptions(
        schema: 'evolutionsport',
      ),
    );

    final supabase = Supabase.instance.client;
    const testEmail = 'test@evolutionsport.com';
    const testPassword = 'password';

    // 2. Crear el usuario de prueba
    print('Creando usuario de prueba: $testEmail');
    final AuthResponse authResponse = await supabase.auth.signUp(
      email: testEmail,
      password: testPassword,
    );

    if (authResponse.user == null) {
      print('Error: No se pudo crear el usuario. ¿Quizás ya existe?');
      // Intentar iniciar sesión si el usuario ya existe
      final res = await supabase.auth.signInWithPassword(email: testEmail, password: testPassword);
      if (res.user == null) {
        throw Exception("No se pudo iniciar sesión con el usuario existente.");
      }
      print("Inicio de sesión exitoso con usuario existente.");
    }
    
    final userId = supabase.auth.currentUser!.id;
    print('Usuario creado/obtenido con ID: $userId');

    // 3. Crear la academia y asociarla al usuario
    print('Creando la academia "Evolution Sport Academy"...');
    final List<Map<String, dynamic>> academies = await supabase
        .from('academies')
        .insert({
          'name': 'Evolution Sport Academy',
          'owner_id': userId,
        })
        .select('id');
    
    if (academies.isEmpty || academies.first['id'] == null) {
        throw Exception("No se pudo crear la academia.");
    }

    final academyId = academies.first['id'];
    print('Academia creada con ID: $academyId');

    // 4. Crear jugadores de prueba para esa academia
    print('Creando jugadores de prueba...');
    await supabase.from('players').insert([
      {
        'name': 'Carlos Rodríguez',
        'academy_id': academyId,
        'sessions_completed': 30,
        'total_sessions': 30
      },
      {
        'name': 'Ana Martínez',
        'academy_id': academyId,
        'sessions_completed': 26,
        'total_sessions': 30
      },
      {
        'name': 'Luis González',
        'academy_id': academyId,
        'sessions_completed': 12,
        'total_sessions': 30
      },
      {
        'name': 'Sofía Fernández',
        'academy_id': academyId,
        'sessions_completed': 0,
        'total_sessions': 30
      },
    ]);
    print('Jugadores creados exitosamente.');
    print('\n¡Siembra de datos completada! 🎉');
    print('Ahora puedes iniciar sesión con:');
    print('Email: $testEmail');
    print('Contraseña: $testPassword');

  } on AuthException catch (e) {
      if (e.message.contains("User already registered")) {
        print("El usuario ya existe, no se tomarán más acciones.");
      } else {
        print("Error de autenticación durante la siembra: ${e.message}");
      }
  } catch (e) {
    print('Ocurrió un error inesperado durante la siembra de datos: $e');
  }
}
