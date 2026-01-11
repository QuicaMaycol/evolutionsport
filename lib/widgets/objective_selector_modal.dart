import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ObjectiveSelectorModal extends StatefulWidget {
  final String? selectedObjectiveId;
  const ObjectiveSelectorModal({super.key, this.selectedObjectiveId});

  @override
  State<ObjectiveSelectorModal> createState() => _ObjectiveSelectorModalState();
}

class _ObjectiveSelectorModalState extends State<ObjectiveSelectorModal> {
  late Future<List<Map<String, dynamic>>> _objectivesFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _objectivesFuture = _loadObjectives();
  }

  Future<List<Map<String, dynamic>>> _loadObjectives() async {
    final response = await Supabase.instance.client
        .from('training_objectives')
        .select()
        .eq('is_active', true)
        .order('category')
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'táctica':
        return Colors.green;
      case 'técnica':
        return Colors.blue;
      case 'física':
        return Colors.red;
      case 'psicológica':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'táctica':
        return Icons.psychology; // Corregido: minúscula
      case 'técnica':
        return Icons.sports_soccer;
      case 'física':
        return Icons.fitness_center;
      case 'psicológica':
        return Icons.groups;
      default:
        return Icons.flag;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Objetivo Principal',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar objetivo...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _objectivesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No se encontraron objetivos'));
                }

                final filtered = snapshot.data!.where((obj) {
                  final name = obj['name'].toString().toLowerCase();
                  final cat = obj['category'].toString().toLowerCase();
                  return name.contains(_searchQuery.toLowerCase()) || 
                         cat.contains(_searchQuery.toLowerCase());
                }).toList();

                // Group by category
                final grouped = <String, List<Map<String, dynamic>>>{};
                for (var obj in filtered) {
                  final cat = obj['category'] as String;
                  if (!grouped.containsKey(cat)) grouped[cat] = [];
                  grouped[cat]!.add(obj);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, index) {
                    final category = grouped.keys.elementAt(index);
                    final items = grouped[category]!;
                    final catColor = _getCategoryColor(category);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: catColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                category.toUpperCase(),
                                style: TextStyle(
                                  color: catColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...items.map((item) {
                          final isSelected = item['id'] == widget.selectedObjectiveId;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? catColor.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? catColor : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                _getCategoryIcon(category),
                                color: isSelected ? catColor : Colors.white38,
                              ),
                              title: Text(
                                item['name'],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              trailing: isSelected 
                                ? Icon(Icons.check_circle, color: catColor)
                                : const Icon(Icons.chevron_right, color: Colors.white10),
                              onTap: () => Navigator.pop(context, item),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
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
