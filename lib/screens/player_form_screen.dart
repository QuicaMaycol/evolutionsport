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
  late TextEditingController _birthDateController; // Nuevo
  String _selectedPosition = 'Medio'; 
  String? _selectedTeamId; // Nuevo
  DateTime? _selectedBirthDate; // Nuevo

  bool _isLoading = false;
  List<Map<String, dynamic>> _teams = []; // Para el Dropdown

  final List<String> _positions = ['Portero', 'Defensa', 'Medio', 'Delantero'];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.player?.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.player?.lastName ?? '');
    _birthDateController = TextEditingController();
    
    // Iniciar con valores si es edición (Falta mapear birthDate en Player model, lo haremos después)
    // Por ahora solo carga posición
    if (widget.player != null && _positions.contains(widget.player!.position)) {
      _selectedPosition = widget.player!.position;
    }
    
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('academy_id')
          .eq('id', user.id)
          .single();
      
      final academyId = profile['academy_id'];
      
      final response = await Supabase.instance.client
          .from('teams')
          .select('id, name')
          .eq('academy_id', academyId);
      
      if (mounted) {
        setState(() {
          _teams = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      // Handle error silently or show snackbar
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2010),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _savePlayer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('academy_id')
          .eq('id', user.id)
          .single();

      final academyId = profileResponse['academy_id'];
      if (academyId == null) throw Exception('Usuario no tiene academia asignada');

      final data = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'position': _selectedPosition,
        'academy_id': academyId,
        'team_id': _selectedTeamId, // Nuevo
        'birth_date': _selectedBirthDate?.toIso8601String(), // Nuevo
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.player == null) {
        await Supabase.instance.client.from('players').insert(data);
      } else {
        await Supabase.instance.client
            .from('players')
            .update(data)
            .eq('id', widget.player!.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jugador guardado exitosamente')),
        );
        Navigator.pop(context, true);
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
          child: ListView( // Cambiado a ListView para scroll
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person)),
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Apellido', prefixIcon: Icon(Icons.person_outline)),
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              
              // Fecha de Nacimiento
              TextFormField(
                controller: _birthDateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Fecha de Nacimiento',
                  prefixIcon: Icon(Icons.cake),
                ),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),

              // Selector de Equipo/Grupo
              DropdownButtonFormField<String>(
                value: _selectedTeamId,
                decoration: const InputDecoration(
                  labelText: 'Grupo / Categoría',
                  prefixIcon: Icon(Icons.groups),
                ),
                items: _teams.map((team) {
                  return DropdownMenuItem<String>(
                    value: team['id'],
                    child: Text(team['name']),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedTeamId = newValue;
                  });
                },
                hint: const Text('Seleccionar Grupo'),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedPosition,
                decoration: const InputDecoration(
                  labelText: 'Posición',
                  prefixIcon: Icon(Icons.sports_soccer),
                ),
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
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEditing ? 'Actualizar' : 'Guardar Jugador',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
