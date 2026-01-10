import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'template_form_screen.dart';

class TemplateLibraryScreen extends StatefulWidget {
  const TemplateLibraryScreen({super.key});

  @override
  State<TemplateLibraryScreen> createState() => _TemplateLibraryScreenState();
}

class _TemplateLibraryScreenState extends State<TemplateLibraryScreen> {
  late Future<List<Map<String, dynamic>>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _refreshTemplates();
  }

  void _refreshTemplates() {
    setState(() {
      _templatesFuture = _loadTemplates();
    });
  }

  Future<List<Map<String, dynamic>>> _loadTemplates() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    try {
      final response = await Supabase.instance.client
          .from('templates')
          .select('*')
          .eq('creator_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Biblioteca Táctica'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _templatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.library_books_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No tienes plantillas creadas.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _navigateToForm(),
                    child: const Text('Crear mi primera plantilla'),
                  ),
                ],
              ),
            );
          }

          final templates = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final t = templates[index];
              final isForSale = t['is_for_sale'] == true;
              final type = _translateType(t['type']);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isForSale ? Colors.amber.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    child: Icon(
                      isForSale ? Icons.storefront : Icons.lock,
                      color: isForSale ? Colors.amber : Colors.grey,
                    ),
                  ),
                  title: Text(t['title'] ?? 'Sin Título', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type),
                      if (isForSale)
                        Text(
                          'Precio: \$${t['price']}',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _navigateToForm(existingTemplate: t);
                      } else if (value == 'delete') {
                        _deleteTemplate(t['id']);
                      }
                    },
                  ),
                  isThreeLine: true,
                  onTap: () => _navigateToForm(existingTemplate: t),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _translateType(String? type) {
    switch (type) {
      case 'session': return 'Sesión Única';
      case 'microcycle': return 'Microciclo (Semana)';
      case 'mesocycle': return 'Mesociclo (Mes)';
      case 'season': return 'Temporada (Año)';
      default: return 'Plantilla';
    }
  }

  Future<void> _navigateToForm({Map<String, dynamic>? existingTemplate}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TemplateFormScreen(template: existingTemplate),
      ),
    );
    if (result == true) {
      _refreshTemplates();
    }
  }

  Future<void> _deleteTemplate(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Plantilla'),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('templates').delete().eq('id', id);
      _refreshTemplates();
    }
  }
}
