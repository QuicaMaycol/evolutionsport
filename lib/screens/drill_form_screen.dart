import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/objective_selector_modal.dart';

import 'tactical_board_screen.dart';

class DrillFormScreen extends StatefulWidget {
  final Map<String, dynamic>? drill;
  final File? initialBoardImage; // Nuevo parámetro
  const DrillFormScreen({super.key, this.drill, this.initialBoardImage});

  @override
  State<DrillFormScreen> createState() => _DrillFormScreenState();
}

class _DrillFormScreenState extends State<DrillFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _minPlayersController = TextEditingController(text: '1');
  final _materialsController = TextEditingController();

  List<Map<String, dynamic>> _selectedObjectives = [];
  bool _isSaving = false;
  bool _isPublic = false;
  
  // Multimedia states
  String _mediaType = 'youtube'; // 'youtube' or 'image'
  String? _imageUrl;
  File? _imageFile;
  String? _youtubeThumbnail;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    
    // Prioridad a la imagen de la pizarra si viene de la sesión rápida
    if (widget.initialBoardImage != null) {
      _imageFile = widget.initialBoardImage;
      _mediaType = 'board';
    }

    if (widget.drill != null) {
      _titleController.text = widget.drill!['title'] ?? '';
      _descController.text = widget.drill!['description'] ?? '';
      _minPlayersController.text = (widget.drill!['min_players'] ?? 1).toString();
      _materialsController.text = (widget.drill!['materials'] as List? ?? []).join(', ');
      _isPublic = widget.drill!['is_public'] ?? false;
      
      final url = widget.drill!['multimedia_url'] as String?;
      if (url != null && url.isNotEmpty) {
        if (url.contains('youtube.com') || url.contains('youtu.be')) {
          _mediaType = 'youtube';
          _youtubeController.text = url;
          _updateYoutubeThumbnail(url);
        } else {
          _mediaType = 'image';
          _imageUrl = url;
        }
      }
    }

    _youtubeController.addListener(() {
      _updateYoutubeThumbnail(_youtubeController.text);
    });
  }

  void _updateYoutubeThumbnail(String url) {
    final videoId = _extractYoutubeId(url);
    if (videoId != null) {
      setState(() {
        _youtubeThumbnail = 'https://img.youtube.com/vi/$videoId/0.jpg';
      });
    } else {
      setState(() {
        _youtubeThumbnail = null;
      });
    }
  }

  String? _extractYoutubeId(String url) {
    if (url.contains('youtu.be/')) {
      return url.split('youtu.be/').last.split('?').first;
    } else if (url.contains('v=')) {
      return url.split('v=').last.split('&').first;
    }
    return null;
  }

  Future<void> _openTacticalBoard() async {
    final File? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TacticalBoardScreen()),
    );
    if (result != null) {
      setState(() {
        _imageFile = result;
        _mediaType = 'board';
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
        _mediaType = 'image';
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _imageUrl;

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'drill_images/$fileName';
      
      await Supabase.instance.client.storage
          .from('drills')
          .upload(path, _imageFile!);
      
      return Supabase.instance.client.storage
          .from('drills')
          .getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading: $e');
      return null;
    }
  }

  Future<void> _pickObjective() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ObjectiveSelectorModal(),
    );

    if (result != null) {
      if (!_selectedObjectives.any((obj) => obj['id'] == result['id'])) {
        setState(() => _selectedObjectives.add(result));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('profiles').select('academy_id').eq('id', user!.id).single();
      
      String? finalUrl;
      if (_mediaType == 'image' || _mediaType == 'board') {
        finalUrl = await _uploadImage();
      } else {
        finalUrl = _youtubeController.text.trim();
      }

      final materials = _materialsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final objectiveIds = _selectedObjectives.map((e) => e['id'] as String).toList();

      final data = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'multimedia_url': finalUrl,
        'min_players': int.tryParse(_minPlayersController.text) ?? 1,
        'materials': materials,
        'objective_ids': objectiveIds,
        'is_public': _isPublic,
        'creator_id': user.id,
        'academy_id': profile['academy_id'],
      };

      if (widget.drill == null) {
        await Supabase.instance.client.from('drills').insert(data);
      } else {
        await Supabase.instance.client.from('drills').update(data).eq('id', widget.drill!['id']);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: Text(widget.drill == null ? 'Nuevo Ejercicio' : 'Editar Ejercicio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Título del Ejercicio', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              
              // SECTOR MULTIMEDIA PROFESIONAL
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Contenido Multimedia', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _mediaTypeButton(label: 'Video YouTube', type: 'youtube', icon: Icons.play_circle_fill),
                        const SizedBox(width: 12),
                        _mediaTypeButton(label: 'Imagen / Galería', type: 'image', icon: Icons.image),
                        const SizedBox(width: 12),
                        _mediaTypeButton(label: 'Pizarra Táctica', type: 'board', icon: Icons.palette),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_mediaType == 'youtube') ...[
                      TextFormField(
                        controller: _youtubeController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Pega el link de YouTube aquí...',
                          prefixIcon: Icon(Icons.link, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_youtubeThumbnail != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.network(_youtubeThumbnail!, height: 120, width: double.infinity, fit: BoxFit.cover),
                                Container(color: Colors.black.withOpacity(0.26), height: 120, width: double.infinity),
                                const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                              ],
                            ),
                          ),
                        ),
                    ] else if (_mediaType == 'board' || _mediaType == 'image') ...[
                      InkWell(
                        onTap: _mediaType == 'board' ? _openTacticalBoard : _pickImage,
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12, style: BorderStyle.solid),
                          ),
                          child: _imageFile != null 
                              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_imageFile!, fit: BoxFit.cover))
                              : _imageUrl != null
                                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_imageUrl!, fit: BoxFit.cover))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(_mediaType == 'board' ? Icons.draw : Icons.add_a_photo, color: Colors.white38, size: 32),
                                        const SizedBox(height: 8),
                                        Text(_mediaType == 'board' ? 'Abrir pizarra táctica' : 'Subir foto de la pizarra', style: const TextStyle(color: Colors.white38)),
                                      ],
                                    ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _descController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Descripción / Instrucciones', border: OutlineInputBorder()),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              
              const Text('Objetivos de este Ejercicio', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ..._selectedObjectives.map((obj) => Chip(
                    label: Text(obj['name'], style: const TextStyle(fontSize: 12)),
                    onDeleted: () => setState(() => _selectedObjectives.remove(obj)),
                  )),
                  ActionChip(
                    label: const Text('Añadir Objetivo'),
                    avatar: const Icon(Icons.add, size: 16),
                    onPressed: _pickObjective,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minPlayersController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Mín. Jugadores', border: OutlineInputBorder(), prefixIcon: Icon(Icons.people_outline)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SwitchListTile(
                      title: const Text('Público', style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: _isPublic,
                      onChanged: (val) => setState(() => _isPublic = val),
                      activeColor: const Color(0xFF4CAF50),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _materialsController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Materiales (separados por coma)', hintText: 'Conos, Petos, Balones', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Guardar en mi Banco', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaTypeButton({required String label, required String type, required IconData icon}) {
    final isSelected = _mediaType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _mediaType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFF4CAF50) : Colors.white12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF4CAF50) : Colors.white38, size: 24),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
