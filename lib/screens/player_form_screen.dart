import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player.dart';

class PlayerFormScreen extends StatefulWidget {
  final Player? player; // If null, we are creating. If not, we are editing.

  const PlayerFormScreen({super.key, this.player});

  @override
  State<PlayerFormScreen> createState() => _PlayerFormScreenState();
}

class _PlayerFormScreenState extends State<PlayerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  String _selectedPosition = 'Medio'; // Default value
  bool _isLoading = false;

  final List<String> _positions = ['Portero', 'Defensa', 'Medio', 'Delantero'];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.player?.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.player?.lastName ?? '',
    );
    if (widget.player != null && _positions.contains(widget.player!.position)) {
      _selectedPosition = widget.player!.position;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _savePlayer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // Get academy_id for the current user
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('academy_id')
          .eq('id', user.id)
          .single();

      final academyId = profileResponse['academy_id'];
      if (academyId == null)
        throw Exception('Usuario no tiene academia asignada');

      final data = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'position': _selectedPosition,
        'academy_id': academyId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.player == null) {
        // Create
        await Supabase.instance.client.from('players').insert(data);
      } else {
        // Update
        await Supabase.instance.client
            .from('players')
            .update(data)
            .eq('id', widget.player!.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jugador guardado exitosamente')),
        );
        Navigator.pop(context, true); // Return true to indicate refresh needed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.player != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Jugador' : 'Nuevo Jugador'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Apellido'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPosition,
                decoration: const InputDecoration(labelText: 'Posición'),
                items: _positions.map((String position) {
                  return DropdownMenuItem<String>(
                    value: position,
                    child: Text(position),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedPosition = newValue!;
                  });
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePlayer,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isEditing ? 'Actualizar' : 'Crear'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
