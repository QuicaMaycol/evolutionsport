import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'session_form_screen.dart';
import 'tactical_board_screen.dart';
import 'drill_form_screen.dart';

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

  Future<void> _quickDrillFromBoard() async {
    final File? boardImage = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TacticalBoardScreen()),
    );

    if (boardImage != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DrillFormScreen(
            initialBoardImage: boardImage,
          ),
        ),
      );
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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionFormScreen(initialDate: _selectedDate),
      ),
    );

    if (result == true) {
      _loadEvents();
    }
  }

  Future<void> _showImportDialog() async {
    List<Map<String, dynamic>> templates = [];
    try {
      // ACTUALIZADO: Usar tabla 'templates' y filtrar por tipo
      final response = await Supabase.instance.client
          .from('templates')
          .select('id, title, description, is_for_sale, type, price');
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
            const Text('Aplica una estructura predefinida.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            if (templates.isEmpty)
              const Text('No hay plantillas disponibles.', style: TextStyle(color: Colors.white))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: templates.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final t = templates[index];
                    final isPremium = t['is_for_sale'] == true;
                    return ListTile(
                      title: Row(
                        children: [
                          Expanded(child: Text(t['title'] ?? 'Sin Título', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          if (isPremium)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                              child: Text('\$${t['price']}', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                        ],
                      ),
                      subtitle: Text('${t['type']} • ${t['description'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                      trailing: const Icon(Icons.download, color: Color(0xFF4CAF50)),
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        Navigator.pop(context);
                        _applyTemplate(t['id']);
                      },
                    );
                  },
                ),
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
      // Si es freelancer sin academia, quizas no tenga equipos, manejar eso?
      // Por ahora asumimos logica de club
      if (profile['academy_id'] != null) {
        final teamResp = await Supabase.instance.client.from('teams').select('id, name').eq('academy_id', profile['academy_id']);
        teams = List<Map<String, dynamic>>.from(teamResp);
      }
    } catch (e) {}

    // Permitir aplicar sin equipo (generales) o requerir equipo
    // Para simplificar, si no hay equipos, aplicamos sin team_id (null)
    
    if (teams.isNotEmpty) {
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
              onPressed: () {
                Navigator.pop(context);
                _processImport(templateId, selectedTeamId);
              },
              child: const Text('Aplicar', style: TextStyle(color: Color(0xFF4CAF50))),
            ),
          ],
        ),
      );
    } else {
      _processImport(templateId, null);
    }
  }

  Future<void> _processImport(String templateId, String? teamId) async {
    setState(() => _isLoading = true);
    try {
      // 1. Obtener contenido JSON de la plantilla
      final tpl = await Supabase.instance.client
          .from('templates')
          .select('content, type')
          .eq('id', templateId)
          .single();
      
      final content = tpl['content'];
      if (content == null || content is! List) {
        throw Exception("La plantilla está vacía o tiene formato inválido.");
      }

      final startOfRange = _selectedDate; // Aplicar a partir de la fecha seleccionada
      
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('profiles').select('academy_id').eq('id', user!.id).single();

      // 2. Iterar e insertar
      for (var item in content) {
        final dayOffset = item['day_offset'] as int;
        final targetDate = startOfRange.add(Duration(days: dayOffset));
        
        final timeStr = item['start_hour'] as String; // "08:00"
        final timeParts = timeStr.split(':');
        final startTime = DateTime(targetDate.year, targetDate.month, targetDate.day, int.parse(timeParts[0]), int.parse(timeParts[1]));
        
        final duration = item['duration_minutes'] as int? ?? 90;

        await Supabase.instance.client.from('events').insert({
          'title': item['title'],
          'session_type': item['session_type'],
          'rpe': item['rpe'],
          'team_id': teamId,
          'academy_id': profile['academy_id'], // Puede ser null si es freelancer puro
          'start_time': startTime.toIso8601String(),
          'end_time': startTime.add(Duration(minutes: duration)).toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plantilla cargada exitosamente 🚀')));
      }
      _loadEvents();

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al importar: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showSaveTemplateDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0.00');
    
    // Fecha base para el guardado (por defecto la seleccionada en calendario)
    DateTime baseDate = _selectedDate;
    
    bool isMarketplace = false;
    String selectedType = 'microcycle'; // Default

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Calcular texto del rango para mostrar al usuario
          String rangeText = '';
          if (selectedType == 'session') {
            rangeText = DateFormat.yMMMMd('es_ES').format(baseDate);
          } else if (selectedType == 'microcycle') {
            final start = baseDate.subtract(Duration(days: baseDate.weekday - 1));
            final end = start.add(const Duration(days: 6));
            final f = DateFormat.MMMd('es_ES');
            rangeText = "${f.format(start)} - ${f.format(end)}";
          } else if (selectedType == 'mesocycle') {
            rangeText = DateFormat.yMMMM('es_ES').format(baseDate);
          } else if (selectedType == 'season') {
            rangeText = "Año ${baseDate.year}";
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            title: const Text('Guardar Plantilla', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Configuración', style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Nombre de la Plantilla', labelStyle: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    dropdownColor: const Color(0xFF333333),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Tipo de Periodo', labelStyle: TextStyle(color: Colors.grey)),
                    items: const [
                      DropdownMenuItem(value: 'session', child: Text('Sesión (1 Día)')),
                      DropdownMenuItem(value: 'microcycle', child: Text('Microciclo (1 Semana)')),
                      DropdownMenuItem(value: 'mesocycle', child: Text('Mesociclo (1 Mes)')),
                      DropdownMenuItem(value: 'season', child: Text('Temporada (1 Año)')),
                    ],
                    onChanged: (val) => setState(() => selectedType = val!),
                  ),
                  const SizedBox(height: 16),
                  
                  // Selector de Fecha Base
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: baseDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Color(0xFF4CAF50),
                                onPrimary: Colors.white,
                                surface: Color(0xFF2D2D2D),
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() => baseDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha de Origen',
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today, color: Colors.white70),
                      ),
                      child: Text(
                        rangeText,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Descripción', labelStyle: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white24),
                  SwitchListTile(
                    title: const Text('Vender en Marketplace', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Disponible para otros usuarios', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                        labelText: r'Precio ($)',
                        labelStyle: TextStyle(color: Colors.grey),
                        prefixText: r'$ ',
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
                    selectedType,
                    baseDate, // Pasamos la fecha elegida
                  );
                },
                child: const Text('Guardar', style: TextStyle(color: Color(0xFF4CAF50))),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _processSaveTemplate(String name, String desc, bool isPublic, double price, String type, DateTime originDate) async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      // 1. Determinar Rango de Fechas basado en 'type' y 'originDate'
      DateTime startRange;
      DateTime endRange;

      if (type == 'session') {
        startRange = DateTime(originDate.year, originDate.month, originDate.day);
        endRange = startRange.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
      } else if (type == 'microcycle') {
        // Semana completa (Lunes a Domingo) de la fecha elegida
        startRange = originDate.subtract(Duration(days: originDate.weekday - 1));
        startRange = DateTime(startRange.year, startRange.month, startRange.day);
        endRange = startRange.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
      } else if (type == 'mesocycle') {
        // Mes completo de la fecha elegida
        startRange = DateTime(originDate.year, originDate.month, 1);
        endRange = DateTime(originDate.year, originDate.month + 1, 0, 23, 59, 59);
      } else if (type == 'season') {
        // Año completo
        startRange = DateTime(originDate.year, 1, 1);
        endRange = DateTime(originDate.year, 12, 31, 23, 59, 59);
      } else {
        startRange = originDate;
        endRange = originDate.add(const Duration(days: 7));
      }

      final profile = await Supabase.instance.client.from('profiles').select('academy_id').eq('id', user!.id).single();
      final academyId = profile['academy_id'];

      // 2. Fetch Eventos reales de la BD para ese rango
      // IMPORTANTE: Consultamos la BD para tener todos los datos, incluso si la vista actual no los muestra
      final eventsResp = await Supabase.instance.client
          .from('events')
          .select('*')
          .eq('academy_id', academyId) // Filtrar por academia actual (o null si freelance)
          .gte('start_time', startRange.toIso8601String())
          .lte('start_time', endRange.toIso8601String());
      
      final eventsToSave = List<Map<String, dynamic>>.from(eventsResp);

      if (eventsToSave.isEmpty) {
        throw Exception("No hay sesiones planificadas en el periodo seleccionado ($type).");
      }

      // 3. Serializar a JSON (Relative Format)
      final List<Map<String, dynamic>> jsonContent = [];

      for (var e in eventsToSave) {
        final eDate = DateTime.parse(e['start_time']);
        
        // Calcular offset relativo al inicio del rango
        // Para sesión: offset 0 (o la hora)
        // Para semana: 0-6
        // Para mes: 0-30
        final diff = eDate.difference(startRange);
        final dayOffset = diff.inDays;
        
        // Hora de inicio string
        final timeStr = "${eDate.hour.toString().padLeft(2,'0')}:${eDate.minute.toString().padLeft(2,'0')}";
        
        // Duración
        final endDate = DateTime.parse(e['end_time']);
        final duration = endDate.difference(eDate).inMinutes;

        jsonContent.add({
          'day_offset': dayOffset,
          'title': e['title'],
          'session_type': e['session_type'],
          'rpe': e['rpe'],
          'start_hour': timeStr,
          'duration_minutes': duration,
        });
      }

      // 4. Insertar en tabla 'templates' (JSONB)
      await Supabase.instance.client.from('templates').insert({
        'title': name, // Ojo: campo se llama 'title' en nueva tabla, antes 'name'
        'description': desc,
        'type': type,
        'is_for_sale': isPublic,
        'price': isPublic ? price : 0.0,
        'creator_id': user.id, // Usamos creator_id, no owner_id
        'content': jsonContent, // JSONB magico
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plantilla guardada en tu Biblioteca 📚')));
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
                      _getMonthName(_selectedDate),
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
            heroTag: 'boardBtn',
            onPressed: _quickDrillFromBoard,
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            icon: const Icon(Icons.palette),
            label: const Text('Pizarra Táctica', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
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
    // Usamos una fecha ficticia que sabemos que es Lunes (ej. 2024-01-01)
    // y le sumamos (day - 1) para obtener el nombre correcto
    final date = DateTime(2024, 1, 1).add(Duration(days: day - 1));
    return DateFormat.E('es_ES').format(date);
  }

  String _getMonthName(DateTime date) {
    return DateFormat.yMMMM('es_ES').format(date); // Ej: "Enero 2026"
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
