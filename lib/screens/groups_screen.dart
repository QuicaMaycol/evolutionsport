import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  bool _isAdmin = false;
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoad();
  }

  Future<void> _checkRoleAndLoad() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();

    setState(() {
      _isAdmin = profile['role'] == 'admin';
    });

    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      // Cargamos grupos y el nombre del entrenador asignado
      final response = await Supabase.instance.client
          .from('teams')
          .select('*, profiles:coach_id(full_name)')
          .order('name');

      if (mounted) {
        setState(() {
          _groups = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _createOrEditGroup({Map<String, dynamic>? group}) async {
    final nameController = TextEditingController(text: group?['name'] ?? '');
    String? selectedCoachId = group?['coach_id'];

    // Cargar lista de entrenadores para el selector
    final coachesResp = await Supabase.instance.client
        .from('profiles')
        .select('id, full_name')
        .eq('academy_id', (await _getAcademyId())!)
        .eq('role', 'coach');
    
    final coaches = List<Map<String, dynamic>>.from(coachesResp);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              group == null ? 'Crear Nuevo Grupo' : 'Editar Grupo',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nombre del Grupo (Ej: Sub-15 Mañana)',
                prefixIcon: Icon(Icons.group_work, color: Colors.white70),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCoachId,
              dropdownColor: const Color(0xFF2D2D2D),
              decoration: const InputDecoration(
                labelText: 'Entrenador a Cargo',
                prefixIcon: Icon(Icons.sports, color: Colors.white70),
                border: OutlineInputBorder(),
              ),
              items: coaches.map((coach) {
                return DropdownMenuItem<String>(
                  value: coach['id'],
                  child: Text(
                    coach['full_name'] ?? 'Sin nombre',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (val) => selectedCoachId = val,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final academyId = await _getAcademyId();
                if (academyId == null) return;

                try {
                  if (group == null) {
                    // Create
                    await Supabase.instance.client.from('teams').insert({
                      'name': name,
                      'coach_id': selectedCoachId,
                      'academy_id': academyId,
                    });
                  } else {
                    // Update
                    await Supabase.instance.client.from('teams').update({
                      'name': name,
                      'coach_id': selectedCoachId,
                    }).eq('id', group['id']);
                  }
                  
                  if (context.mounted) Navigator.pop(context);
                  _loadGroups();
                } catch (e) {
                  // Handle error
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                group == null ? 'Crear Grupo' : 'Guardar Cambios',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _getAcademyId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final res = await Supabase.instance.client.from('profiles').select('academy_id').eq('id', user.id).single();
    return res['academy_id'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grupos de Entrenamiento')),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _createOrEditGroup(),
              backgroundColor: const Color(0xFF4CAF50),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nuevo Grupo', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? Center(
                  child: Text(
                    'No hay grupos creados.\nCrea uno para empezar a organizar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    final coachName = group['profiles']?['full_name'] ?? 'Sin asignar';

                    return GestureDetector(
                      onTap: _isAdmin ? () => _createOrEditGroup(group: group) : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D2D2D),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.groups, color: Color(0xFF4CAF50)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group['name'],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.person_outline, size: 14, color: Colors.white.withOpacity(0.5)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Profe: $coachName',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (_isAdmin)
                              Icon(Icons.edit, color: Colors.white.withOpacity(0.3)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
