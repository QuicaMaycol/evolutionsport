import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/objective_selector_modal.dart';
import '../widgets/drill_selector_modal.dart';

import 'drill_form_screen.dart';
import 'tactical_board_screen.dart';
import 'dart:io';

class SessionFormScreen extends StatefulWidget {
  final DateTime initialDate;
  const SessionFormScreen({super.key, required this.initialDate});

  @override
  State<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends State<SessionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  
  String? _selectedTeamId;
  Map<String, dynamic>? _selectedObjective;
  List<Map<String, dynamic>> _suggestedDrills = [];
  List<Map<String, dynamic>> _selectedDrills = [];
  String _stimulusType = 'Campo';
  double _rpeLoad = 5.0;
  final _notesController = TextEditingController();
  
  bool _isSaving = false;
  bool _isLoadingDrills = false;
  bool _saveAsTemplate = false;
  List<Map<String, dynamic>> _teams = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('profiles').select('academy_id').eq('id', user!.id).single();
      final academyId = profile['academy_id'];
      
      if (academyId != null) {
        final teamResp = await Supabase.instance.client.from('teams').select('id, name').eq('academy_id', academyId);
        setState(() {
          _teams = List<Map<String, dynamic>>.from(teamResp);
          if (_teams.isNotEmpty) _selectedTeamId = _teams.first['id'];
        });
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    }
  }

  Future<void> _quickDrillFromBoard() async {
    // 1. Abrir pizarra
    final File? boardImage = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TacticalBoardScreen()),
    );

    if (boardImage != null && mounted) {
      // 2. Si dibujó algo, abrir formulario de ejercicio con esa imagen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DrillFormScreen(
            initialBoardImage: boardImage,
          ),
        ),
      );

      // 3. Si guardó el ejercicio, refrescar sugerencias
      if (result == true && _selectedObjective != null) {
        _loadSuggestedDrills(_selectedObjective!['id']);
      }
    }
  }

  Future<void> _loadSuggestedDrills(String objectiveId) async {
    setState(() => _isLoadingDrills = true);
    try {
      // Buscar ejercicios que contengan este objetivo en su array objective_ids
      final response = await Supabase.instance.client
          .from('drills')
          .select()
          .contains('objective_ids', [objectiveId]);
      
      setState(() {
        _suggestedDrills = List<Map<String, dynamic>>.from(response);
        _isLoadingDrills = false;
      });
    } catch (e) {
      debugPrint('Error loading suggested drills: $e');
      setState(() => _isLoadingDrills = false);
    }
  }

  Future<void> _showObjectiveSelector() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ObjectiveSelectorModal(selectedObjectiveId: _selectedObjective?['id']),
    );

    if (result != null) {
      setState(() {
        _selectedObjective = result;
        _suggestedDrills = [];
      });
      _loadSuggestedDrills(result['id']);
    }
  }

  Future<void> _showAllDrillsSelector() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DrillSelectorModal(
        excludedIds: _selectedDrills.map((d) => d['id'] as String).toList(),
        initialObjectiveId: _selectedObjective?['id'],
      ),
    );

    if (result != null) {
      _addDrillToSession(result);
    }
  }

  void _addDrillToSession(Map<String, dynamic> drill) {
    if (!_selectedDrills.any((d) => d['id'] == drill['id'])) {
      setState(() {
        _selectedDrills.add({
          ...drill,
          'duration': 15, // Duración por defecto
        });
      });
    }
  }

  Future<void> _saveSession() async {
    if (_selectedObjective == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor selecciona un objetivo principal')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('profiles').select('academy_id').eq('id', user!.id).single();
      final academyId = profile['academy_id'];

      // 1. Guardar la Sesión
      final sessionData = {
        'academy_id': academyId,
        'team_id': _selectedTeamId,
        'date': _selectedDate.toIso8601String().split('T')[0],
        'start_time': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00',
        'main_objective_id': _selectedObjective!['id'],
        'rpe_load': _rpeLoad.toInt(),
        'stimulus_type': _stimulusType,
        'notes': _notesController.text.trim(),
        'creator_id': user.id,
      };

      final sessionResponse = await Supabase.instance.client
          .from('sessions')
          .insert(sessionData)
          .select()
          .single();

      final sessionId = sessionResponse['id'];

      // 2. Guardar los ejercicios de la sesión (session_drills)
      if (_selectedDrills.isNotEmpty) {
        final sessionDrillsData = _selectedDrills.asMap().entries.map((entry) {
          final index = entry.key;
          final drill = entry.value;
          return {
            'session_id': sessionId,
            'drill_id': drill['id'],
            'order_index': index,
            'duration_minutes': drill['duration'],
          };
        }).toList();

        await Supabase.instance.client.from('session_drills').insert(sessionDrillsData);
      }

      // 3. Si se marcó como plantilla, guardarla también
      if (_saveAsTemplate) {
        await Supabase.instance.client.from('templates').insert({
          'title': '${_selectedObjective!['name']} - Plan',
          'description': _notesController.text.trim(),
          'main_objective_id': _selectedObjective!['id'],
          'rpe_load': _rpeLoad.toInt(),
          'stimulus_type': _stimulusType,
          'creator_id': user.id,
          'academy_id': academyId,
          'type': 'session',
          'content': _selectedDrills, // Guardamos la lista de ejercicios en el JSONB
        });
      }

      // 4. Crear evento en el calendario (para compatibilidad actual)
      final startDateTime = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _startTime.hour, _startTime.minute,
      );
      
      await Supabase.instance.client.from('events').insert({
        'title': _selectedObjective!['name'],
        'team_id': _selectedTeamId,
        'academy_id': academyId,
        'start_time': startDateTime.toIso8601String(),
        'end_time': startDateTime.add(const Duration(hours: 1, minutes: 30)).toIso8601String(),
        'session_type': _stimulusType.toLowerCase() == 'campo' ? 'training' : _stimulusType.toLowerCase(),
        'rpe': _rpeLoad.toInt(),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesión planificada exitosamente 🚀')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Planificar Sesión'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fecha y Hora
              Row(
                children: [
                  Expanded(
                    child: _buildPickerTile(
                      label: 'Fecha',
                      value: '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      icon: Icons.calendar_today,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPickerTile(
                      label: 'Hora',
                      value: _startTime.format(context),
                      icon: Icons.access_time,
                      onTap: () async {
                        final picked = await showTimePicker(context: context, initialTime: _startTime);
                        if (picked != null) setState(() => _startTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Grupo
              const Text('Grupo / Categoría', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedTeamId,
                dropdownColor: const Color(0xFF2D2D2D),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: _teams.map((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['name'], style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (val) => setState(() => _selectedTeamId = val),
              ),
              const SizedBox(height: 24),

              // Objetivo Principal
              const Text('Objetivo Principal', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _showObjectiveSelector,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _selectedObjective != null 
                        ? _getCategoryColor(_selectedObjective!['category']).withOpacity(0.1)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedObjective != null 
                          ? _getCategoryColor(_selectedObjective!['category'])
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedObjective != null ? Icons.check_circle : Icons.ads_click,
                        color: _selectedObjective != null 
                            ? _getCategoryColor(_selectedObjective!['category'])
                            : Colors.white38,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedObjective != null ? _selectedObjective!['name'] : 'Seleccionar objetivo...',
                          style: TextStyle(
                            color: _selectedObjective != null ? Colors.white : Colors.white38,
                            fontSize: 16,
                            fontWeight: _selectedObjective != null ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white38),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // SECCIÓN DE EJERCICIOS SUGERIDOS
              if (_selectedObjective != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ejercicios Sugeridos', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _quickDrillFromBoard,
                          icon: const Icon(Icons.palette_outlined, size: 16),
                          label: const Text('Dibujar Idea', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(foregroundColor: Colors.amber),
                        ),
                        TextButton.icon(
                          onPressed: _showAllDrillsSelector,
                          icon: const Icon(Icons.search, size: 16),
                          label: const Text('Ver todos', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF4CAF50)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_suggestedDrills.isEmpty && !_isLoadingDrills)
                  const Text('No hay ejercicios en tu banco para este objetivo.', style: TextStyle(color: Colors.white24, fontSize: 12))
                else
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _suggestedDrills.length > 10 ? 11 : _suggestedDrills.length,
                      itemBuilder: (context, index) {
                        if (index == 10) {
                          return GestureDetector(
                            onTap: _showAllDrillsSelector,
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24, width: 1),
                            ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_circle_outline, color: Colors.white38),
                                  SizedBox(height: 8),
                                  Text('Ver más', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                ],
                              ),
                            ),
                          );
                        }

                        final drill = _suggestedDrills[index];
                        final isAdded = _selectedDrills.any((d) => d['id'] == drill['id']);
                        return GestureDetector(
                          onTap: isAdded ? null : () => _addDrillToSession(drill),
                          child: Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isAdded ? Colors.green : Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    ),
                                    child: const Center(child: Icon(Icons.fitness_center, color: Colors.white24)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          drill['title'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12, color: isAdded ? Colors.green : Colors.white70),
                                        ),
                                      ),
                                      if (isAdded) const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 32),
              ],

              // LISTA DE EJERCICIOS SELECCIONADOS (EL PLAN)
              if (_selectedDrills.isNotEmpty) ...[
                const Text('Plan de Trabajo', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._selectedDrills.asMap().entries.map((entry) {
                  final index = entry.key;
                  final drill = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.05),
                          child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(drill['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text('${drill['min_players']}+ jugadores', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Selector de minutos
                        Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.24),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: drill['duration'],
                              dropdownColor: const Color(0xFF2D2D2D),
                              isExpanded: true,
                              items: [5, 10, 15, 20, 30, 45].map((m) => DropdownMenuItem(value: m, child: Text('$m min', style: const TextStyle(color: Colors.white, fontSize: 12)))).toList(),
                              onChanged: (val) => setState(() => drill['duration'] = val),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => setState(() => _selectedDrills.removeAt(index)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 32),
              ],

              // Tipo de Estímulo
              const Text('Tipo de Estímulo', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Campo', 'Físico/Gym', 'Partido', 'Recuperación', 'Video'].map((type) {
                  final isSelected = _stimulusType == type;
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStimulusIcon(type),
                          size: 16,
                          color: isSelected ? const Color(0xFF4CAF50) : Colors.white38,
                        ),
                        const SizedBox(width: 8),
                        Text(type),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _stimulusType = type),
                    selectedColor: const Color(0xFF4CAF50).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF4CAF50) : Colors.white60,
                      fontSize: 13,
                    ),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(color: isSelected ? const Color(0xFF4CAF50) : Colors.white12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // RPE
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Carga (RPE)', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text(
                    _rpeLoad.toInt().toString(),
                    style: TextStyle(
                      color: _getIntensityColor(_rpeLoad.toInt()),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _rpeLoad,
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: _getIntensityColor(_rpeLoad.toInt()),
                onChanged: (val) => setState(() => _rpeLoad = val),
              ),
              const SizedBox(height: 24),

              // Notas
              TextField(
                controller: _notesController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Notas / Observaciones',
                  labelStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),

              // Guardar como Plantilla
              SwitchListTile(
                title: const Text('Guardar como Plantilla', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Podrás reutilizar este plan en el futuro', style: TextStyle(color: Colors.white38, fontSize: 12)),
                value: _saveAsTemplate,
                onChanged: (val) => setState(() => _saveAsTemplate = val),
                activeColor: const Color(0xFF4CAF50),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Planificar Sesión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerTile({required String label, required String value, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, color: const Color(0xFF4CAF50), size: 16),
                const SizedBox(width: 8),
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStimulusIcon(String type) {
    switch (type) {
      case 'Campo': return Icons.sports_soccer;
      case 'Físico/Gym': return Icons.fitness_center;
      case 'Partido': return Icons.stadium;
      case 'Recuperación': return Icons.spa;
      case 'Video': return Icons.videocam;
      default: return Icons.directions_run;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'táctica': return Colors.green;
      case 'técnica': return Colors.blue;
      case 'física': return Colors.red;
      case 'psicológica': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Color _getIntensityColor(int rpe) {
    if (rpe >= 8) return const Color(0xFFEF5350);
    if (rpe >= 5) return const Color(0xFFFFCA28);
    return const Color(0xFF66BB6A);
  }
}
