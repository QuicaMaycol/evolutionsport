import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Super Admin'),
        backgroundColor: Colors.blueGrey.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4CAF50),
          tabs: const [
            Tab(icon: Icon(Icons.business), text: 'Academias'),
            Tab(icon: Icon(Icons.library_books), text: 'Biblioteca'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AcademiesTab(),
          _TemplatesTab(),
        ],
      ),
    );
  }
}

class _AcademiesTab extends StatefulWidget {
  const _AcademiesTab();

  @override
  State<_AcademiesTab> createState() => _AcademiesTabState();
}

class _AcademiesTabState extends State<_AcademiesTab> {
  late Future<List<Map<String, dynamic>>> _academiesFuture;

  @override
  void initState() {
    super.initState();
    _loadAcademies();
  }

  void _loadAcademies() {
    setState(() {
      _academiesFuture = Supabase.instance.client
          .from('academies')
          .select('*')
          .order('created_at', ascending: false)
          .then((data) => List<Map<String, dynamic>>.from(data));
    });
  }

  Future<void> _toggleAcademyStatus(String academyId, bool currentStatus) async {
    try {
      await Supabase.instance.client
          .from('academies')
          .update({'is_active': !currentStatus})
          .eq('id', academyId);
      
      _loadAcademies();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _academiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final academies = snapshot.data ?? [];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: academies.length,
          itemBuilder: (context, index) {
            final academy = academies[index];
            final isActive = academy['is_active'] as bool? ?? true;
            return Card(
              color: isActive ? const Color(0xFF2D2D2D) : const Color(0xFF1F1F1F),
              child: ListTile(
                title: Text(academy['name'] ?? 'Sin nombre', style: TextStyle(color: isActive ? Colors.white : Colors.grey)),
                trailing: Switch(
                  value: isActive,
                  activeColor: const Color(0xFF4CAF50),
                  onChanged: (val) => _toggleAcademyStatus(academy['id'], isActive),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TemplatesTab extends StatefulWidget {
  const _TemplatesTab();

  @override
  State<_TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<_TemplatesTab> {
  late Future<List<Map<String, dynamic>>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  void _loadTemplates() {
    setState(() {
      _templatesFuture = Supabase.instance.client
          .from('training_templates')
          .select('*')
          .eq('is_global', true) // Solo ver las globales que gestiono yo
          .order('created_at', ascending: false)
          .then((data) => List<Map<String, dynamic>>.from(data));
    });
  }

  Future<void> _createTemplate() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: "0.0");
    bool isPremium = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nueva Plantilla Global'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('¿Es Premium?'),
                value: isPremium,
                onChanged: (val) => setState(() => isPremium = val),
              ),
              if (isPremium)
                TextField(
                  controller: priceCtrl, 
                  decoration: const InputDecoration(labelText: 'Precio', prefixText: '\$'),
                  keyboardType: TextInputType.number,
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            TextButton(
              onPressed: () async {
                await Supabase.instance.client.from('training_templates').insert({
                  'name': nameCtrl.text,
                  'is_global': true,
                  'is_premium': isPremium,
                  'price': double.tryParse(priceCtrl.text) ?? 0.0,
                });
                if(mounted) Navigator.pop(context);
                _loadTemplates();
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _createTemplate,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _templatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final templates = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final t = templates[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    t['is_premium'] ? Icons.workspace_premium : Icons.public,
                    color: t['is_premium'] ? Colors.amber : Colors.blue,
                  ),
                  title: Text(t['name']),
                  subtitle: Text(t['is_premium'] ? '\$${t['price']}' : 'Gratis'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await Supabase.instance.client.from('training_templates').delete().eq('id', t['id']);
                      _loadTemplates();
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
