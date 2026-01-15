import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DrillSelectorModal extends StatefulWidget {
  final List<String> excludedIds;
  final String? initialObjectiveId;
  final String? categoryFilter; // Nuevo parámetro

  const DrillSelectorModal({
    super.key, 
    required this.excludedIds,
    this.initialObjectiveId,
    this.categoryFilter,
  });

  @override
  State<DrillSelectorModal> createState() => _DrillSelectorModalState();
}

class _DrillSelectorModalState extends State<DrillSelectorModal> {
  late Future<List<Map<String, dynamic>>> _drillsFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _drillsFuture = _loadDrills();
  }

  Future<List<Map<String, dynamic>>> _loadDrills() async {
    final user = Supabase.instance.client.auth.currentUser;
    final profile = await Supabase.instance.client.from('profiles').select('academy_id').eq('id', user!.id).single();
    final academyId = profile['academy_id'];

    // 1. Cargar ejercicios con filtro de categoría opcional
    var query = Supabase.instance.client
        .from('drills')
        .select('*');

    // Aplicar filtro de categoría si existe
    if (widget.categoryFilter != null) {
      query = query.eq('category', widget.categoryFilter!);
    }

    final response = await query
        .or('is_public.eq.true${academyId != null ? ", academy_id.eq.$academyId" : ""}')
        .order('title');
    
    final drills = List<Map<String, dynamic>>.from(response);

    // 2. Cargar objetivos para mapeo (opcional para visualización)
    // ... (Mantenemos la lógica existente de objetivos si se usa)
    
    // 3. Filtrar excluidos
    return drills.where((d) => !widget.excludedIds.contains(d['id'])).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Explorar Banco', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white54)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar ejercicio...',
                    prefixIcon: const Icon(Icons.search, color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                if (widget.categoryFilter != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Chip(
                      label: Text(
                        _getCategoryLabel(widget.categoryFilter!), 
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
                      ),
                      backgroundColor: _getCategoryColor(widget.categoryFilter!),
                      avatar: const Icon(Icons.filter_list, size: 16, color: Colors.black),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _drillsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No hay ejercicios en esta categoría'));

                final filtered = snapshot.data!.where((d) {
                  return d['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final drill = filtered[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.fitness_center, color: _getCategoryColor(widget.categoryFilter ?? 'main')),
                        title: Text(drill['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('${drill['min_players']}+ jugadores', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        trailing: Icon(Icons.add_circle_outline, color: _getCategoryColor(widget.categoryFilter ?? 'main')),
                        onTap: () => Navigator.pop(context, drill),
                      ),
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

  String _getCategoryLabel(String cat) {
    switch (cat) {
      case 'warmup': return 'Fase: Activación';
      case 'cooldown': return 'Fase: Vuelta a la Calma';
      default: return 'Fase: Principal';
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'warmup': return Colors.amber;
      case 'cooldown': return Colors.greenAccent;
      default: return const Color(0xFF4CAF50);
    }
  }
}
