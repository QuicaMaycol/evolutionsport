import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player.dart';
import 'package:intl/intl.dart';

class PlayerProfileScreen extends StatefulWidget {
  final Player player;
  const PlayerProfileScreen({super.key, required this.player});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _measurementsFuture;
  late Future<List<Map<String, dynamic>>> _evaluationsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _measurementsFuture = _loadMeasurements();
      _evaluationsFuture = _loadEvaluations();
    });
  }

  Future<List<Map<String, dynamic>>> _loadMeasurements() async {
    final response = await Supabase.instance.client
        .schema('evolutionsport')
        .from('player_measurements')
        .select()
        .eq('player_id', widget.player.id)
        .order('measured_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _loadEvaluations() async {
    final response = await Supabase.instance.client
        .schema('evolutionsport')
        .from('player_match_evaluations')
        .select()
        .eq('player_id', widget.player.id)
        .order('match_date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A1A),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blue.withOpacity(0.4), Colors.black],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      child: Text(
                        widget.player.position[0],
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.player.fullName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      widget.player.position,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.blueAccent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'Evolución'),
                  Tab(text: 'Antropometría'),
                  Tab(text: 'Rendimiento'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildMeasurementsTab(),
            _buildPerformanceTab(),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      backgroundColor: Colors.blueAccent,
      onPressed: () {
        if (_tabController.index == 1) {
          _showMeasurementForm();
        } else if (_tabController.index == 2) {
          _showEvaluationForm();
        }
      },
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard('Datos Generales', [
            _buildInfoRow('Edad', '${_calculateAge(widget.player.birthDate)} años'),
            _buildInfoRow('Sesiones completadas', '${widget.player.sessionsCompleted}'),
            _buildInfoRow('Última asistencia', DateFormat('dd/MM/yyyy').format(widget.player.lastAttendance)),
          ]),
          const SizedBox(height: 24),
          const Text('Progreso Reciente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Center(child: Text('Gráfico de evolución próximamente', style: TextStyle(color: Colors.grey))),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _measurementsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        if (data.isEmpty) {
          return const Center(child: Text('No hay registros antropométricos todavía', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final m = data[index];
            final date = DateFormat('dd/MM/yyyy').format(DateTime.parse(m['measured_at']));
            return Card(
              color: Colors.white.withOpacity(0.05),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                title: Text('Medición del $date', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text('Peso: ${m['weight']}kg | Altura: ${m['height']}cm', style: const TextStyle(color: Colors.blueAccent)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildSmallStat('Cabeza', '${m['head_circumference']}'),
                        _buildSmallStat('Cuello', '${m['neck_circumference']}'),
                        _buildSmallStat('Brazo (R)', '${m['arm_relaxed']}'),
                        _buildSmallStat('Bíceps', '${m['arm_contracted']}'),
                        _buildSmallStat('Cintura', '${m['waist_circumference']}'),
                        _buildSmallStat('Muslo (S)', '${m['thigh_upper']}'),
                        _buildSmallStat('Muslo (M)', '${m['thigh_mid']}'),
                        _buildSmallStat('Pantorrilla', '${m['calf_circumference']}'),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPerformanceTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _evaluationsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;
        if (data.isEmpty) {
          return const Center(child: Text('No hay evaluaciones de partido todavía', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final e = data[index];
            final date = DateFormat('dd/MM/yyyy').format(DateTime.parse(e['match_date']));
            return Card(
              color: Colors.white.withOpacity(0.05),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber.withOpacity(0.2),
                  child: Text('${e['rating']}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                ),
                title: Text('vs ${e['opponent'] ?? 'Desconocido'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('$date | ${e['minutes_played']} min jugados', style: const TextStyle(color: Colors.grey)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => _showEvaluationDetails(e),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, String value) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  int _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return 0;
    return DateTime.now().year - birthDate.year;
  }

  void _showMeasurementForm() {
    final weightController = TextEditingController();
    final heightController = TextEditingController();
    final headController = TextEditingController();
    final neckController = TextEditingController();
    final armRController = TextEditingController();
    final armCController = TextEditingController();
    final waistController = TextEditingController();
    final thighUController = TextEditingController();
    final thighMController = TextEditingController();
    final calfController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nueva Medición Antropométrica', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildField('Peso (kg)', weightController)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildField('Altura (cm)', heightController)),
                ],
              ),
              const Divider(height: 40, color: Colors.white10),
              const Text('Perímetros (cm)', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildField('Cabeza', headController),
              _buildField('Cuello', neckController),
              Row(
                children: [
                  Expanded(child: _buildField('Brazo Relaj.', armRController)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildField('Bíceps Cont.', armCController)),
                ],
              ),
              _buildField('Cintura', waistController),
              Row(
                children: [
                  Expanded(child: _buildField('Muslo Superior', thighUController)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildField('Muslo Medio', thighMController)),
                ],
              ),
              _buildField('Pantorrilla', calfController),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: () async {
                    try {
                      await Supabase.instance.client.schema('evolutionsport').from('player_measurements').insert({
                        'player_id': widget.player.id,
                        'weight': double.tryParse(weightController.text),
                        'height': double.tryParse(heightController.text),
                        'head_circumference': double.tryParse(headController.text),
                        'neck_circumference': double.tryParse(neckController.text),
                        'arm_relaxed': double.tryParse(armRController.text),
                        'arm_contracted': double.tryParse(armCController.text),
                        'waist_circumference': double.tryParse(waistController.text),
                        'thigh_upper': double.tryParse(thighUController.text),
                        'thigh_mid': double.tryParse(thighMController.text),
                        'calf_circumference': double.tryParse(calfController.text),
                      });
                      Navigator.pop(context);
                      _refreshData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text('Guardar Registro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  void _showEvaluationForm() {
    final opponentController = TextEditingController();
    final minutesController = TextEditingController();
    final notesController = TextEditingController();
    double technical = 3;
    double tactical = 3;
    double physical = 3;
    double mental = 3;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Evaluación de Competencia', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 24),
                _buildField('Rival / Oponente', opponentController),
                _buildField('Minutos Jugados', minutesController),
                const Divider(height: 40, color: Colors.white10),
                _buildScoreSlider('Técnico', technical, (val) => setModalState(() => technical = val)),
                _buildScoreSlider('Táctico', tactical, (val) => setModalState(() => tactical = val)),
                _buildScoreSlider('Físico', physical, (val) => setModalState(() => physical = val)),
                _buildScoreSlider('Mental', mental, (val) => setModalState(() => mental = val)),
                const SizedBox(height: 24),
                _buildField('Notas de partido', notesController),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    onPressed: () async {
                      try {
                        final avgRating = (technical + tactical + physical + mental) / 2;
                        await Supabase.instance.client.schema('evolutionsport').from('player_match_evaluations').insert({
                          'player_id': widget.player.id,
                          'opponent': opponentController.text,
                          'minutes_played': int.tryParse(minutesController.text) ?? 0,
                          'technical_score': technical.toInt(),
                          'tactical_score': tactical.toInt(),
                          'physical_score': physical.toInt(),
                          'mental_score': mental.toInt(),
                          'rating': avgRating,
                          'notes': notesController.text,
                        });
                        Navigator.pop(context);
                        _refreshData();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    child: const Text('Guardar Evaluación', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreSlider(String label, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            Text('${value.toInt()}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: Colors.amber,
          onChanged: onChanged,
        ),
      ],
    );
  }

  void _showEvaluationDetails(Map<String, dynamic> eval) {
    // Mostrar detalles completos
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: const Color(0xFF1A1A1A), child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
