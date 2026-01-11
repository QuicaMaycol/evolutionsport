import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'drill_form_screen.dart'; // Crearemos esto a continuación

class DrillsLibraryScreen extends StatefulWidget {
  const DrillsLibraryScreen({super.key});

  @override
  State<DrillsLibraryScreen> createState() => _DrillsLibraryScreenState();
}

class _DrillsLibraryScreenState extends State<DrillsLibraryScreen> {
  late Future<List<Map<String, dynamic>>> _drillsFuture;
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _refreshDrills();
  }

  void _refreshDrills() {
    setState(() {
      _drillsFuture = _loadDrills();
    });
  }

  Future<List<Map<String, dynamic>>> _loadDrills() async {
    final user = Supabase.instance.client.auth.currentUser;
    final profile = await Supabase.instance.client.from('profiles').select('academy_id').eq('id', user!.id).single();
    final academyId = profile['academy_id'];

    // 1. Cargar ejercicios
    final response = await Supabase.instance.client
        .from('drills')
        .select('*')
        .or('is_public.eq.true${academyId != null ? ", academy_id.eq.$academyId" : ""}')
        .order('created_at', ascending: false);
    
    final drills = List<Map<String, dynamic>>.from(response);

    // 2. Cargar objetivos para mapeo manual (PostgREST no une arrays de UUIDs automáticamente)
    final objResponse = await Supabase.instance.client
        .from('training_objectives')
        .select('id, name, category');
    
    final objectivesMap = { for (var e in objResponse) e['id'] : e };

    // 3. Vincular
    for (var drill in drills) {
      final ids = drill['objective_ids'] as List? ?? [];
      drill['display_objectives'] = ids.map((id) => objectivesMap[id]).where((e) => e != null).toList();
    }
    
    return drills;
  }

  Future<void> _deleteDrill(Map<String, dynamic> drill) async {
    final drillId = drill['id'];
    
    // 1. Verificar uso mediante RPC o consulta simple
    try {
      final inUse = await Supabase.instance.client.rpc('check_drill_in_use', params: {'drill_uuid': drillId});
      
      if (inUse == true) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Acción Bloqueada'),
              content: const Text('Este ejercicio ya está siendo usado en sesiones o plantillas y no puede eliminarse para mantener la integridad de los datos.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
              ],
            ),
          );
        }
        return;
      }

      // 2. Si no está en uso, confirmar eliminación (Borrado lógico)
      if (mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Eliminar Ejercicio?'),
            content: Text('¿Estás seguro de que quieres eliminar "${drill['title']}"? Esta acción no se puede deshacer.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.pop(context, true), 
                child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await Supabase.instance.client.from('drills').update({'is_active': false}).eq('id', drillId);
          _refreshDrills();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Banco de Ejercicios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDrills,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DrillFormScreen()),
          );
          if (result == true) _refreshDrills();
        },
        backgroundColor: const Color(0xFF4CAF50),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo Ejercicio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Buscador y Filtros
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar por título o material...',
                    prefixIcon: const Icon(Icons.search, color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Todos', 'Táctica', 'Técnica', 'Física', 'Psicológica'].map((cat) {
                      final isSelected = (_selectedCategory ?? 'Todos') == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (val) => setState(() => _selectedCategory = cat == 'Todos' ? null : cat),
                          selectedColor: const Color(0xFF4CAF50).withOpacity(0.2),
                          labelStyle: TextStyle(color: isSelected ? const Color(0xFF4CAF50) : Colors.white60),
                          backgroundColor: Colors.transparent,
                          side: BorderSide(color: isSelected ? const Color(0xFF4CAF50) : Colors.white12),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _drillsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ));
                }

                final drills = snapshot.data!;
                final filtered = drills.where((d) {
                  final title = d['title'].toString().toLowerCase();
                  final matchesSearch = title.contains(_searchQuery.toLowerCase());
                  
                  bool matchesCat = true;
                  if (_selectedCategory != null) {
                    final objectives = d['display_objectives'] as List? ?? [];
                    matchesCat = objectives.any((obj) => obj['category'] == _selectedCategory);
                  }

                  return matchesSearch && matchesCat;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fitness_center, size: 64, color: Colors.white10),
                        SizedBox(height: 16),
                        Text('No se encontraron ejercicios', style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final drill = filtered[index];
                    return _DrillCard(
                      drill: drill, 
                      onDelete: () => _deleteDrill(drill),
                      onEdit: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => DrillFormScreen(drill: drill)),
                        );
                        if (result == true) _refreshDrills();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DrillCard extends StatelessWidget {
  final Map<String, dynamic> drill;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  
  const _DrillCard({required this.drill, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final imageUrl = drill['multimedia_url'];
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = drill['creator_id'] == userId;
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Image.network(imageUrl, fit: BoxFit.cover)
                else
                  Container(
                    color: Colors.white.withOpacity(0.05),
                    child: const Icon(Icons.image, color: Colors.white10, size: 48),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people, size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          '${drill['min_players']}+',
                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOwner)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Row(
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          icon: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.edit, size: 12, color: Colors.white),
                          ),
                          onPressed: onEdit,
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          icon: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.delete, size: 12, color: Colors.red),
                          ),
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drill['title'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  drill['description'] ?? 'Sin descripción',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

