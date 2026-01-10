import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _academyCodeController = TextEditingController();
  final _academyNameController = TextEditingController();

  bool _isLoading = false;
  bool _isFreelancer = false;

  void _onCodeChanged(String value) {
    if (value.isNotEmpty && _academyNameController.text.isNotEmpty) {
      _academyNameController.clear();
    }
  }

  void _onNameChanged(String value) {
    if (value.isNotEmpty && _academyCodeController.text.isNotEmpty) {
      _academyCodeController.clear();
    }
  }

  Future<void> _signUp() async {
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final fullName = _fullNameController.text.trim();
      final academyCode = _academyCodeController.text.trim();
      final academyName = _academyNameController.text.trim();

      if (!_isFreelancer && academyCode.isEmpty && academyName.isEmpty) {
        throw const AuthException(
          'Debes ingresar un Código de Invitación O el Nombre de tu Marca/Club.',
        );
      }

      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'io.evolutionsport.app://login-callback',
        data: {
          'full_name': fullName,
          'academy_code': _isFreelancer ? null : academyCode,
          'academy_name': _isFreelancer ? fullName : academyName,
          'is_freelancer': _isFreelancer,
        },
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.mark_email_read, color: Colors.green),
                SizedBox(width: 10),
                Text('¡Registro Exitoso!'),
              ],
            ),
            content: const Text(
              'Hemos enviado un enlace de confirmación a tu correo electrónico.\n\n'
              'Por favor, revisa tu bandeja de entrada (y spam) y confirma tu cuenta para poder iniciar sesión.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Cierra dialogo
                  Navigator.pop(context); // Vuelve al login
                },
                child: const Text('Entendido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error inesperado'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _academyCodeController.dispose();
    _academyNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- OPCIÓN FREELANCER ---
              Container(
                decoration: BoxDecoration(
                  color: _isFreelancer 
                      ? Colors.green.withOpacity(0.1) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: _isFreelancer 
                      ? Border.all(color: Colors.green.withOpacity(0.3)) 
                      : null,
                ),
                child: SwitchListTile(
                  title: const Text('Soy Entrenador Freelancer'),
                  subtitle: const Text('Vende tus plantillas sin unirte a un club'),
                  value: _isFreelancer,
                  onChanged: (val) {
                    setState(() {
                      _isFreelancer = val;
                      if (val) {
                        _academyCodeController.clear();
                        _academyNameController.clear();
                      }
                    });
                  },
                  activeColor: Colors.green,
                ),
              ),
              const SizedBox(height: 24),

              if (!_isFreelancer) ...[
                // --- BLOQUE ENTRENADOR CONTRATADO ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '¿Te uniste a un Club?',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ingresa el código que te dio tu administrador.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _academyCodeController,
                        onChanged: _onCodeChanged,
                        decoration: const InputDecoration(
                          labelText: 'Código de Invitación',
                          prefixIcon: Icon(Icons.vpn_key),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Row(children: [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("O")),
                  Expanded(child: Divider()),
                ]),
                const SizedBox(height: 24),

                // --- BLOQUE INDEPENDIENTE / DUEÑO ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '¿Eres Independiente o Dueño?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Crea tu propia marca personal para gestionar tus tácticas.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _academyNameController,
                        onChanged: _onNameChanged,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de tu Marca / Club',
                          prefixIcon: Icon(Icons.stadium),
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
              
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Tu Nombre Completo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
              
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Registrarse', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
