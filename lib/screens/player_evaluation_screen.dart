import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player.dart';
import '../models/player_evaluation.dart';

class PlayerEvaluationScreen extends StatefulWidget {
  final Player? initialPlayer;

  const PlayerEvaluationScreen({super.key, this.initialPlayer});

  @override
  State<PlayerEvaluationScreen> createState() => _PlayerEvaluationScreenState();
}

class _PlayerEvaluationScreenState extends State<PlayerEvaluationScreen> {
  Player? _selectedPlayer;
  bool _isLoading = false;
  
  // Atributos actuales
  int _pace = 50;
  int _shooting = 50;
  int _passing = 50;
  int _dribbling = 50;
  int _defending = 50;
  int _physical = 50;

  // Datos de Contexto
  Map<String, int>? _ghostStats;
  Map<String, double>? _teamAverages;
  
  String _preferredZone = 'Mediocampo';
  final _notesController = TextEditingController();

  final List<String> _zones = ['Portería', 'Defensa Central', 'Lateral', 'Mediocampo', 'Extremo', 'Delantero Centro'];

  @override
  void initState() {
    super.initState();
    if (widget.initialPlayer != null) {
      _selectPlayer(widget.initialPlayer!);
    }
  }

  void _selectPlayer(Player p) async {
    setState(() {
      _selectedPlayer = p;
      _isLoading = true;
    });
    
    await _loadContextData(p.id);
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadContextData(String playerId) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client.from('profiles').select('academy_id').eq('id', user.id).single();
      final academyId = profile['academy_id'];

      // 1. Cargar "Fantasma" (Última evaluación)
      final lastEval = await Supabase.instance.client
          .from('player_evaluations')
          .select('*')
          .eq('player_id', playerId)
          .order('evaluation_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastEval != null && mounted) {
        setState(() {
          _ghostStats = {
            'pace': lastEval['pace'] ?? 0,
            'shooting': lastEval['shooting'] ?? 0,
            'passing': lastEval['passing'] ?? 0,
            'dribbling': lastEval['dribbling'] ?? 0,
            'defending': lastEval['defending'] ?? 0,
            'physical': lastEval['physical'] ?? 0,
          };
          // Inicializar con valores previos
          _pace = _ghostStats!['pace']!;
          _shooting = _ghostStats!['shooting']!;
          _passing = _ghostStats!['passing']!;
          _dribbling = _ghostStats!['dribbling']!;
          _defending = _ghostStats!['defending']!;
          _physical = _ghostStats!['physical']!;
          _preferredZone = lastEval['preferred_zone'] ?? 'Mediocampo';
          _notesController.text = lastEval['coach_notes'] ?? '';
        });
      }

      // 2. Cargar "Media del Equipo"
      final allEvals = await Supabase.instance.client
          .from('player_evaluations')
          .select('pace, shooting, passing, dribbling, defending, physical')
          .eq('coach_id', user.id);

      if (allEvals != null && (allEvals as List).isNotEmpty && mounted) {
        final evals = allEvals as List;
        setState(() {
          _teamAverages = {
            'pace': evals.map((e) => e['pace'] as int).reduce((a, b) => a + b) / evals.length,
            'shooting': evals.map((e) => e['shooting'] as int).reduce((a, b) => a + b) / evals.length,
            'passing': evals.map((e) => e['passing'] as int).reduce((a, b) => a + b) / evals.length,
            'dribbling': evals.map((e) => e['dribbling'] as int).reduce((a, b) => a + b) / evals.length,
            'defending': evals.map((e) => e['defending'] as int).reduce((a, b) => a + b) / evals.length,
            'physical': evals.map((e) => e['physical'] as int).reduce((a, b) => a + b) / evals.length,
          };
        });
      }
    } catch (e) {
      debugPrint('Error cargando contexto: $e');
    }
  }

  String _getQualitativeLabel(int value) {
    if (value >= 90) return 'Fuera de Serie';
    if (value >= 75) return 'Nivel Élite';
    if (value >= 60) return 'Competitivo';
    if (value >= 40) return 'En Desarrollo';
    return 'Iniciación';
  }

  Color _getQualitativeColor(int value) {
    if (value >= 90) return Colors.cyanAccent;
    if (value >= 75) return Colors.greenAccent;
    if (value >= 60) return Colors.yellowAccent;
    if (value >= 40) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Future<List<Player>> _loadPlayers() async {
    final user = Supabase.instance.client.auth.currentUser;
    final profile = await Supabase.instance.client.from('profiles').select('academy_id').eq('id', user!.id).single();
    
    final response = await Supabase.instance.client
        .from('players')
        .select('*')
        .eq('academy_id', profile['academy_id'])
        .order('first_name');
    
    return (response as List).map((row) => Player.fromMap(row)).toList();
  }

  Future<void> _saveEvaluation() async {
    if (_selectedPlayer == null) return;

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      final evaluation = PlayerEvaluation(
        playerId: _selectedPlayer!.id,
        coachId: user!.id,
        evaluationDate: DateTime.now(),
        pace: _pace,
        shooting: _shooting,
        passing: _passing,
        dribbling: _dribbling,
        defending: _defending,
        physical: _physical,
        preferredZone: _preferredZone,
        coachNotes: _notesController.text,
      );

      await Supabase.instance.client.from('player_evaluations').insert(evaluation.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evaluación de ${_selectedPlayer!.firstName} guardada con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(_selectedPlayer == null ? 'Seleccionar Jugador' : 'Evaluar a ${_selectedPlayer!.firstName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _selectedPlayer == null ? _buildPlayerPicker() : _buildEvaluationForm(),
      bottomNavigationBar: _selectedPlayer != null ? _buildBottomAction() : null,
    );
  }

  Widget _buildPlayerPicker() {
    return FutureBuilder<List<Player>>(
      future: _loadPlayers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final players = snapshot.data!;
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: players.length,
          itemBuilder: (context, index) {
            final p = players[index];
            return Card(
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  child: Text(p.firstName[0], style: const TextStyle(color: Colors.white)),
                ),
                title: Text(p.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(p.position, style: const TextStyle(color: Colors.white54)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                onTap: () => _selectPlayer(p),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEvaluationForm() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Capacidades Técnicas'),
              _buildLegend(),
            ],
          ),
          const SizedBox(height: 24),
          _buildStatSlider('Ritmo (Pace)', _pace, 'pace', (v) => setState(() => _pace = v.toInt())),
          _buildStatSlider('Tiro (Shooting)', _shooting, 'shooting', (v) => setState(() => _shooting = v.toInt())),
          _buildStatSlider('Pase (Passing)', _passing, 'passing', (v) => setState(() => _passing = v.toInt())),
          _buildStatSlider('Regate (Dribbling)', _dribbling, 'dribbling', (v) => setState(() => _dribbling = v.toInt())),
          _buildStatSlider('Defensa (Defending)', _defending, 'defending', (v) => setState(() => _defending = v.toInt())),
          _buildStatSlider('Físico (Physical)', _physical, 'physical', (v) => setState(() => _physical = v.toInt())),
          
          const SizedBox(height: 32),
          _buildSectionTitle('Contexto Táctico'),
          const SizedBox(height: 16),
          _buildZonePicker(),
          
          const SizedBox(height: 32),
          _buildSectionTitle('Notas del Entrenador'),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Escribe aquí tus observaciones...',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _LegendItem(icon: Icons.history, label: 'Pasado', color: Colors.white38),
        const SizedBox(width: 12),
        _LegendItem(icon: Icons.groups, label: 'Media', color: Colors.blueAccent.withOpacity(0.5)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueAccent, letterSpacing: 1.5),
    );
  }

  Widget _buildStatSlider(String label, int value, String key, ValueChanged<double> onChanged) {
    final color = _getQualitativeColor(value);
    final ghostValue = _ghostStats?[key];
    final teamAvg = _teamAverages?[key];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                Text(
                  _getQualitativeLabel(value),
                  style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ],
            ),
            Row(
              children: [
                if (ghostValue != null) ...[
                  _buildDiffIndicator(value, ghostValue),
                  const SizedBox(width: 8),
                ],
                Text(value.toString(), style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                inactiveTrackColor: Colors.white10,
                thumbColor: Colors.white,
                overlayColor: color.withOpacity(0.2),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: value.toDouble(),
                min: 0,
                max: 100,
                onChanged: onChanged,
              ),
            ),
            // Marcas
            Positioned(
              left: 24,
              right: 24,
              bottom: -4,
              child: SizedBox(
                height: 10,
                child: Stack(
                  children: [
                    if (ghostValue != null)
                      Positioned(
                        left: (MediaQuery.of(context).size.width - 96) * (ghostValue / 100),
                        child: Container(width: 2, height: 8, color: Colors.white38),
                      ),
                    if (teamAvg != null)
                      Positioned(
                        left: (MediaQuery.of(context).size.width - 96) * (teamAvg / 100),
                        child: Container(width: 2, height: 8, color: Colors.blueAccent),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDiffIndicator(int current, int previous) {
    final diff = current - previous;
    if (diff == 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (diff > 0 ? Colors.green : Colors.red).withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${diff > 0 ? '+' : ''}$diff',
        style: TextStyle(
          color: diff > 0 ? Colors.greenAccent : Colors.redAccent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildZonePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _preferredZone,
          dropdownColor: const Color(0xFF1E1E1E),
          isExpanded: true,
          style: const TextStyle(color: Colors.white),
          items: _zones.map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
          onChanged: (val) => setState(() => _preferredZone = val!),
          hint: const Text('Zona Preferida', style: TextStyle(color: Colors.white24)),
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
        ),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveEvaluation,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('GUARDAR EVALUACIÓN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _LegendItem({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
