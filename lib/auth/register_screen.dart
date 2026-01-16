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
  bool _isFreelancer = true;

  Future<void> _signUp() async {
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final fullName = _fullNameController.text.trim();
      final academyCode = _academyCodeController.text.trim();
      final academyName = _academyNameController.text.trim();

      if (!_isFreelancer && academyName.isEmpty) {
        throw const AuthException('Debes ingresar el nombre de la academia o empresa.');
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
                Text('Registro Exitoso!'),
              ],
            ),
            content: const Text(
              'Hemos enviado un enlace de confirmacion a tu correo electronico.\n\n'
              'Por favor, revisa tu bandeja de entrada (y spam) y confirma tu cuenta para poder iniciar sesion.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
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
    } catch (_) {
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
      appBar: AppBar(title: const Text('Unete a Direction Futbol Pro')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- OPCION FREELANCER ---
              Container(
                decoration: BoxDecoration(
                  color: _isFreelancer ? Colors.green.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: _isFreelancer ? Border.all(color: Colors.green.withOpacity(0.3)) : null,
                ),
                child: SwitchListTile(
                  title: const Text('Soy Entrenador'),
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
                TextFormField(
                  controller: _academyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de Academia o Empresa',
                    prefixIcon: Icon(Icons.stadium),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
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
                  labelText: 'Contrasena',
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
