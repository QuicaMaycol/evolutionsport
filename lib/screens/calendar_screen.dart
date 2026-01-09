import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

enum CalendarView { micro, meso }

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  CalendarView _currentView = CalendarView.micro;
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = false;

  Color _getIntensityColor(int rpe) {
    if (rpe >= 8) return const Color(0xFFEF5350);
    if (rpe >= 5) return const Color(0xFFFFCA28);
    return const Color(0xFF66BB6A);
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'match':
        return Icons.sports_soccer;
      case 'gym':
        return Icons.fitness_center;
      case 'recovery':
        return Icons.spa;
      case 'theory':
        return Icons.school;
      default:
        return Icons.directions_run;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'match':
        return 'Partido';
      case 'gym':
        return 'Gimnasio';
      case 'recovery':
        return 'Recuperación';
      case 'theory':
        return 'Charla Táctica';
      default:
        return 'Entrenamiento';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final academyResp = await Supabase.instance.client
          .from('profiles')
          .select('academy_id')
          .eq('id', user.id)
          .single();
      final academyId = academyResp['academy_id'];

      DateTime startRange, endRange;

      if (_currentView == CalendarView.micro) {
        startRange = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        endRange = startRange.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
      } else {
        startRange = DateTime(_selectedDate.year, _selectedDate.month, 1);
        endRange = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);
      }

      final response = await Supabase.instance.client
          .from('events')
          .select('*, teams(name)')
          .eq('academy_id', academyId)
          .gte('start_time', startRange.toIso8601String())
          .lte('start_time', endRange.toIso8601String())
          .order('start_time');

      if (mounted) {
        setState(() {
          _events = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addSession() async {
    final titleController = TextEditingController();
    final timeController = TextEditingController(text: "08:00");
    String? selectedTeamId;
    String sessionType = 'training';
    double intensity = 5.0;
    List<Map<String, dynamic>> teams = [];

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('profiles').select('academy_id').eq('id', user!.id).single();
      final teamResp = await Supabase.instance.client.from('teams').select('id, name').eq('academy_id', profile['academy_id']);
      teams = List<Map<String, dynamic>>.from(teamResp);
    } catch (e) {}

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24, right: 24, top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Planificar Sesión', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 24),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Objetivo Principal', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedTeamId,
                  dropdownColor: const Color(0xFF2D2D2D),
                  decoration: const InputDecoration(labelText: 'Grupo / Categoría', border: OutlineInputBorder()),
                  items: teams.map<DropdownMenuItem<String>>((t) => DropdownMenuItem<String>(value: t['id'], child: Text(t['name'], style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (val) => setModalState(() => selectedTeamId = val),
                ),
                const SizedBox(height: 24),
                const Text('Tipo de Estímulo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _ChoiceChip(label: 'Campo', selected: sessionType == 'training', onSelected: (b) => setModalState(() => sessionType = 'training')),
                    _ChoiceChip(label: 'Físico/Gym', selected: sessionType == 'gym', onSelected: (b) => setModalState(() => sessionType = 'gym')),
                    _ChoiceChip(label: 'Partido', selected: sessionType == 'match', color: Colors.blue, onSelected: (b) => setModalState(() => sessionType = 'match')),
                    _ChoiceChip(label: 'Recuperación', selected: sessionType == 'recovery', color: Colors.green, onSelected: (b) => setModalState(() => sessionType = 'recovery')),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Carga (RPE)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF2D2D2D),
                                title: const Text('¿Qué es RPE?', style: TextStyle(color: Colors.white)),
                                content: const Text(
                                  'RPE (Índice de Esfuerzo Percibido) es una escala del 1 al 10.\n\n1-3: Recuperación\n4-6: Mantenimiento\n7-8: Alta Intensidad\n9-10: Máxima exigencia',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido', style: TextStyle(color: Color(0xFF4CAF50)))),
                                ],
                              ),
                            );
                          },
                          child: Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    Text(intensity.toInt().toString(), style: TextStyle(color: _getIntensityColor(intensity.toInt()), fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Slider(
                  value: intensity,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  activeColor: _getIntensityColor(intensity.toInt()),
                  onChanged: (val) => setModalState(() => intensity = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: timeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Hora de Inicio', border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time)),
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.isEmpty || selectedTeamId == null) return;
                      try {
                        final timeParts = timeController.text.split(':');
                        final startTime = DateTime(
                          _selectedDate.year, _selectedDate.month, _selectedDate.day,
                          int.parse(timeParts[0]), int.parse(timeParts[1]),
                        );
                        
                        final user = Supabase.instance.client.auth.currentUser;
                        final profile = await Supabase.instance.client.from('profiles').select('academy_id').eq('id', user!.id).single();

                        await Supabase.instance.client.from('events').insert({
                          'title': titleController.text,
                          'team_id': selectedTeamId,
                          'academy_id': profile['academy_id'],
                          'start_time': startTime.toIso8601String(),
                          'end_time': startTime.add(const Duration(hours: 2)).toIso8601String(),
                          'session_type': sessionType,
                          'rpe': intensity.toInt(),
                        });
                        
                        if (context.mounted) Navigator.pop(context);
                        _loadEvents();
                      } catch (e) {}
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Guardar Sesión', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showImportDialog() async {
    List<Map<String, dynamic>> templates = [];
    try {
      final response = await Supabase.instance.client.from('training_templates').select('id, name, description, is_premium');
      templates = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Importar Plantilla', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Aplica una estructura predefinida a esta semana.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            // CORRECCIÓN AQUÍ: Estructura simple sin ifs complejos dentro de la lista
            if (templates.isEmpty)
              const Text('No hay plantillas disponibles.', style: TextStyle(color: Colors.white))
            else
              Column(
                children: templates.map((t) {
                  final isPremium = t['is_premium'] == true;
                  return ListTile(
                    title: Row(
                      children: [
                        Text(t['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        if (isPremium) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                            child: const Text('PRO', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        ]
                      ],
                    ),
                    subtitle: Text(t['description'] ?? '', style: const TextStyle(color: Colors.white70)),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF4CAF50)),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.pop(context);
                      _applyTemplate(t['id']);
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyTemplate(String templateId) async {
    String? selectedTeamId;
    List<Map<String, dynamic>> teams = [];
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('profiles').select('academy_id').eq('id', user!.id).single();
      final teamResp = await Supabase.instance.client.from('teams').select('id, name').eq('academy_id', profile['academy_id']);
      teams = List<Map<String, dynamic>>.from(teamResp);
    } catch (e) {}

    if (teams.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Crea primero un grupo de entrenamiento.')));
        return;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('¿A qué grupo?', style: TextStyle(color: Colors.white)),
        content: DropdownButtonFormField<String>(
          dropdownColor: const Color(0xFF333333),
          items: teams.map<DropdownMenuItem<String>>((t) => DropdownMenuItem<String>(value: t['id'], child: Text(t['name'], style: const TextStyle(color: Colors.white)))).toList(),
          onChanged: (val) => selectedTeamId = val,
          hint: const Text('Seleccionar Equipo', style: TextStyle(color: Colors.white70)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              if (selectedTeamId != null) {
                Navigator.pop(context);
                _processImport(templateId, selectedTeamId!);
              }
            },
            child: const Text('Aplicar', style: TextStyle(color: Color(0xFF4CAF50))),
          ),
        ],
      ),
    );
  }

  Future<void> _processImport(String templateId, String teamId) async {
    setState(() => _isLoading = true);
    try {
      final itemsResp = await Supabase.instance.client.from('template_items').select().eq('template_id', templateId);
      final items = List<Map<String, dynamic>>.from(itemsResp);

      final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('profiles').select('academy_id').eq('id', user!.id).single();

      for (var item in items) {
        final dayOffset = item['day_offset'] as int;
        final targetDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day).add(Duration(days: dayOffset));
        final timeStr = item['start_hour'] as String;
        final timeParts = timeStr.split(':');
        final startTime = DateTime(targetDate.year, targetDate.month, targetDate.day, int.parse(timeParts[0]), int.parse(timeParts[1]));

        await Supabase.instance.client.from('events').insert({
          'title': item['title'],
          'session_type': item['session_type'],
          'rpe': item['rpe'],
          'team_id': teamId,
          'academy_id': profile['academy_id'],
          'start_time': startTime.toIso8601String(),
          'end_time': startTime.add(Duration(minutes: item['duration_minutes'] ?? 90)).toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semana planificada con éxito 🚀')));
      }
      _loadEvents();

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showSaveTemplateDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0.00');
    bool isMarketplace = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text('Guardar Semana', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Nombre de la Plantilla', labelStyle: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Descripción', labelStyle: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text('Publicar en Mercado', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Véndela a otros entrenadores', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  value: isMarketplace,
                  activeColor: const Color(0xFF4CAF50),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => isMarketplace = val),
                ),
                if (isMarketplace)
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                    labelText: 'Precio (\$)',
                      labelStyle: TextStyle(color: Colors.grey),
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                Navigator.pop(context);
                _processSaveTemplate(
                  nameCtrl.text,
                  descCtrl.text,
                  isMarketplace,
                  double.tryParse(priceCtrl.text) ?? 0.0,
                );
              },
              child: const Text('Guardar', style: TextStyle(color: Color(0xFF4CAF50))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processSaveTemplate(String name, String desc, bool isPublic, double price) async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('profiles').select('id').eq('id', user!.id).single();

      final tplResp = await Supabase.instance.client.from('training_templates').insert({
        'name': name,
        'description': desc,
        'is_global': false, 
        'is_marketplace': isPublic,
        'price': isPublic ? price : 0.0,
        'owner_id': profile['id'],
      }).select().single();
      
      final templateId = tplResp['id'];

      final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));

      final eventsToSave = _events.where((e) {
        final date = DateTime.parse(e['start_time']);
        return date.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && 
               date.isBefore(endOfWeek);
      }).toList();

      if (eventsToSave.isEmpty) {
        throw Exception("No hay eventos en esta semana para guardar.");
      }

      for (var e in eventsToSave) {
        final eDate = DateTime.parse(e['start_time']);
        final offset = eDate.weekday - 1; 
        final duration = DateTime.parse(e['end_time']).difference(eDate).inMinutes;
        final timeStr = "${eDate.hour.toString().padLeft(2,'0')}:${eDate.minute.toString().padLeft(2,'0')}";

        await Supabase.instance.client.from('template_items').insert({
          'template_id': templateId,
          'day_offset': offset,
          'title': e['title'],
          'session_type': e['session_type'],
          'rpe': e['rpe'],
          'start_hour': timeStr,
          'duration_minutes': duration,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plantilla guardada y lista para usar 💾')));
      }

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: PopupMenuButton<CalendarView>(
                onSelected: (CalendarView result) {
                  setState(() {
                    _currentView = result;
                    _loadEvents();
                  });
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<CalendarView>>[
                  const PopupMenuItem<CalendarView>(
                    value: CalendarView.micro,
                    child: Text('Microciclo (Semana)'),
                  ),
                  const PopupMenuItem<CalendarView>(
                    value: CalendarView.meso,
                    child: Text('Mesociclo (Mes)'),
                  ),
                ],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _currentView == CalendarView.micro ? 'Microciclo' : 'Mesociclo',
                          style: const TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                      ],
                    ),
                    Text(
                      "${_getMonthName(_selectedDate.month)} ${_selectedDate.year}",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'Guardar Semana como Plantilla',
              onPressed: _showSaveTemplateDialog,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  if (_currentView == CalendarView.micro) {
                    _selectedDate = _selectedDate.subtract(const Duration(days: 7));
                  } else {
                    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                  }
                  _loadEvents();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  if (_currentView == CalendarView.micro) {
                    _selectedDate = _selectedDate.add(const Duration(days: 7));
                  } else {
                    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                  }
                  _loadEvents();
                });
              },
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'importBtn',
            onPressed: _showImportDialog,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF4CAF50),
            icon: const Icon(Icons.copy_all),
            label: const Text('Cargar Plantilla', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'addBtn',
            onPressed: _addSession,
            backgroundColor: const Color(0xFF4CAF50),
            icon: const Icon(Icons.add_task, color: Colors.white),
            label: const Text("Planificar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_currentView == CalendarView.micro)
            _buildMicrocycleStrip(),

          if (_currentView == CalendarView.meso)
            Expanded(child: _buildMesocycleGrid()),
          
          if (_currentView == CalendarView.micro)
            const Divider(height: 1, color: Colors.white10),
          
          if (_currentView == CalendarView.micro)
            Expanded(child: _buildSessionList()),
        ],
      ),
    );
  }

  Widget _buildMicrocycleStrip() {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = startOfWeek.add(Duration(days: index));
          final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;
          final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;
          
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _loadEvents();
            },
            child: Container(
              width: (MediaQuery.of(context).size.width - 32) / 7,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2D2D2D) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected 
                    ? Border.all(color: const Color(0xFF4CAF50), width: 2) 
                    : (isToday ? Border.all(color: Colors.white24) : null),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getWeekDay(date.weekday).toUpperCase().substring(0, 1),
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? const Color(0xFF4CAF50) : Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      color: isSelected ? Colors.white : (isToday ? const Color(0xFF4CAF50) : Colors.white),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMesocycleGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final int firstWeekday = firstDayOfMonth.weekday;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                .map((d) => Text(d, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))
                .toList(),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.8),
            itemCount: daysInMonth + (firstWeekday - 1),
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) return const SizedBox.shrink();
              
              final dayNum = index - (firstWeekday - 1) + 1;
              final currentDayDate = DateTime(_selectedDate.year, _selectedDate.month, dayNum);
              
              final dayEvents = _events.where((e) {
                final eDate = DateTime.parse(e['start_time']).toLocal();
                return eDate.day == dayNum;
              }).toList();

              Color? dayColor;
              if (dayEvents.isNotEmpty) {
                int maxRpe = 0;
                for (var e in dayEvents) {
                  final rpe = e['rpe'] as int? ?? 0;
                  if (rpe > maxRpe) maxRpe = rpe;
                }
                dayColor = _getIntensityColor(maxRpe).withOpacity(0.2);
                if (dayEvents.any((e) => e['session_type'] == 'match')) {
                  dayColor = Colors.blue.withOpacity(0.3);
                }
              }

              final isSelected = dayNum == _selectedDate.day;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = currentDayDate;
                    _currentView = CalendarView.micro;
                    _loadEvents();
                  });
                },
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: dayColor ?? const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayNum.toString(),
                        style: TextStyle(
                          color: dayEvents.isNotEmpty ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      if (dayEvents.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: dayColor != null ? dayColor.withOpacity(1) : Colors.white,
                            shape: BoxShape.circle,
                          ),
                        )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSessionList() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _events.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_soccer, size: 64, color: Colors.white.withOpacity(0.1)),
                    const SizedBox(height: 16),
                    Text(
                      'Día de descanso',
                      style: TextStyle(color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final event = _events[index];
                  final time = DateTime.parse(event['start_time']).toLocal();
                  final timeStr = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                  final rpe = event['rpe'] as int? ?? 5;
                  final type = event['session_type'] as String? ?? 'training';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            decoration: BoxDecoration(
                              color: _getIntensityColor(rpe),
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                                        child: Row(
                                          children: [
                                            Icon(Icons.access_time, size: 12, color: Colors.white70),
                                            const SizedBox(width: 4),
                                            Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                          ],
                                        ),
                                      ),
                                      Icon(_getTypeIcon(type), color: Colors.white24, size: 20),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(event['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text(event['teams']?['name'] ?? 'General', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6))),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _Tag(label: _getTypeLabel(type), color: Colors.blue),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor: const Color(0xFF2D2D2D),
                                              title: const Text('¿Qué es RPE?', style: TextStyle(color: Colors.white)),
                                              content: const Text(
                                                'RPE (Índice de Esfuerzo Percibido) es una escala del 1 al 10.\n\n1-3: Recuperación\n4-6: Mantenimiento\n7-8: Alta Intensidad\n9-10: Máxima exigencia',
                                                style: TextStyle(color: Colors.white70),
                                              ),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido', style: TextStyle(color: Color(0xFF4CAF50)))),
                                              ],
                                            ),
                                          );
                                        },
                                        child: _Tag(label: 'RPE $rpe (i)', color: _getIntensityColor(rpe)),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
  }

  String _getWeekDay(int day) {
    const days = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];
    return days[day - 1];
  }

  String _getMonthName(int month) {
    const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return months[month - 1];
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color color;

  const _ChoiceChip({required this.label, required this.selected, required this.onSelected, this.color = const Color(0xFF4CAF50)});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: selected ? color : Colors.white60, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
      backgroundColor: Colors.transparent,
      side: BorderSide(color: selected ? color : Colors.white12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.5)), borderRadius: BorderRadius.circular(4), color: color.withOpacity(0.1)),
      child: Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
