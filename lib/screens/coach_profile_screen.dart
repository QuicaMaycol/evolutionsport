import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachProfileScreen extends StatefulWidget {
  final String? coachId; // Si es null, mostramos el perfil del usuario actual

  const CoachProfileScreen({super.key, this.coachId});

  @override
  State<CoachProfileScreen> createState() => _CoachProfileScreenState();
}

class _CoachProfileScreenState extends State<CoachProfileScreen> {
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _myTemplates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final targetId = widget.coachId ?? Supabase.instance.client.auth.currentUser?.id;
      if (targetId == null) return;

      // 1. Cargar Perfil
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('*, academies(name)')
          .eq('id', targetId)
          .single();

      // 2. Cargar Mis Plantillas (Las que yo creé)
      // Ajustamos nombre de tabla 'templates' (antes buscaba training_templates)
      // y 'creator_id' (antes owner_id)
      final templatesResponse = await Supabase.instance.client
          .from('templates') 
          .select('*')
          .eq('creator_id', targetId);

      if (mounted) {
        setState(() {
          _profileData = profileResponse;
          _myTemplates = List<Map<String, dynamic>>.from(templatesResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_profileData == null) return const Scaffold(body: Center(child: Text('Perfil no encontrado')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil Profesional'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildCareerStats(),
            const SizedBox(height: 24),
            _buildSectionTitle('Mi Biblioteca Táctica'),
            _buildTemplateGrid(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final academyName = _profileData!['academies']?['name'] ?? 'Independiente';
    final name = _profileData!['full_name'] ?? 'Entrenador';
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF4CAF50).withOpacity(0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 32, color: Color(0xFF4CAF50), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    academyName,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareerStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'Plantillas', value: _myTemplates.length.toString()),
          const SizedBox(
            height: 30,
            child: VerticalDivider(color: Colors.white10),
          ),
          _StatItem(label: 'Impacto RPE', value: 'N/A', color: Colors.grey),
          const SizedBox(
            height: 30,
            child: VerticalDivider(color: Colors.white10),
          ),
          _StatItem(label: 'Ventas', value: '0'),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextButton(onPressed: () {}, child: const Text('Ver todo')),
        ],
      ),
    );
  }

  Widget _buildTemplateGrid() {
    if (_myTemplates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Text('Aún no has creado plantillas propias.', style: TextStyle(color: Colors.white24)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _myTemplates.length,
      itemBuilder: (context, index) {
        final t = _myTemplates[index];
        final isPublic = t['is_for_sale'] == true;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(16),
            border: isPublic ? Border.all(color: Colors.amber.withOpacity(0.3)) : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Icon(isPublic ? Icons.storefront : Icons.lock_outline, color: isPublic ? Colors.amber : Colors.white24),
            title: Text(t['title'] ?? 'Sin Título', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(isPublic ? 'Publicado - \$${t['price']}' : 'Privado', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white10),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color ?? Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
