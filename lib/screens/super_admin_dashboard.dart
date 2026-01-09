import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  late Future<List<Map<String, dynamic>>> _academiesFuture;

  @override
  void initState() {
    super.initState();
    _academiesFuture = _loadAcademies();
  }

  Future<List<Map<String, dynamic>>> _loadAcademies() async {
    final response = await Supabase.instance.client
        .from('academies')
        .select('*')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _toggleAcademyStatus(String academyId, bool currentStatus) async {
    try {
      await Supabase.instance.client
          .from('academies')
          .update({'is_active': !currentStatus})
          .eq('id', academyId);
      
      setState(() {
        _academiesFuture = _loadAcademies();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !currentStatus ? 'Academia Activada' : 'Academia Desactivada',
            ),
            backgroundColor: !currentStatus ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _academiesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final academies = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: academies.length,
            itemBuilder: (context, index) {
              final academy = academies[index];
              final isActive = academy['is_active'] as bool? ?? true;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: isActive ? const Color(0xFF2D2D2D) : const Color(0xFF1F1F1F),
                shape: RoundedRectangleBorder(
                  side: isActive 
                    ? BorderSide.none 
                    : BorderSide(color: Colors.red.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    academy['name'] ?? 'Sin nombre',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isActive ? Colors.white : Colors.grey,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'ID: ${academy['id']}\nCreada: ${academy['created_at'].toString().split('T')[0]}',
                      style: const TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ),
                  trailing: Switch(
                    value: isActive,
                    activeColor: const Color(0xFF4CAF50),
                    inactiveTrackColor: Colors.red.withOpacity(0.3),
                    inactiveThumbColor: Colors.red,
                    onChanged: (value) => _toggleAcademyStatus(
                      academy['id'],
                      isActive,
                    ),
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
