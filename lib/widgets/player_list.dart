import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player.dart';
import '../screens/player_form_screen.dart';
import '../screens/player_profile_screen.dart';
import 'attendance_insights_bar.dart';

class PlayerList extends StatefulWidget {
  final Future<List<Player>> playersFuture;
  final Future<void> Function()? onRefresh;
  final bool showControls;
  final bool hideMarkedToday;
  final Future<String>? userRoleFuture;

  const PlayerList({
    super.key,
    required this.playersFuture,
    this.onRefresh,
    this.showControls = false,
    this.hideMarkedToday = false,
    this.userRoleFuture,
  });

  @override
  State<PlayerList> createState() => _PlayerListState();
}

class _PlayerListState extends State<PlayerList> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedPosition;
  List<Player> _allPlayers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant PlayerList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playersFuture != oldWidget.playersFuture) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final players = await widget.playersFuture;
      if (mounted) {
        setState(() {
          _allPlayers = players;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  Future<void> _incrementAttendance(Player player) async {
    try {
      final newCount = player.sessionsCompleted + 1;
      final now = DateTime.now();

      await Supabase.instance.client.from('players').update({
        'sessions_completed': newCount,
        'last_attendance': now.toIso8601String(),
      }).eq('id', player.id);

      setState(() {
        final index = _allPlayers.indexWhere((p) => p.id == player.id);
        if (index != -1) {
          _allPlayers[index] = Player(
            id: player.id,
            firstName: player.firstName,
            lastName: player.lastName,
            position: player.position,
            sessionsCompleted: newCount,
            lastAttendance: now,
            birthDate: player.birthDate,
          );
        }
      });
    } catch (e) {
      debugPrint('Error al marcar asistencia: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text('Error: $_errorMessage'));

    final filteredPlayers = _allPlayers.where((player) {
      final matchesSearch = '${player.firstName} ${player.lastName}'
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
      final matchesPosition =
          _selectedPosition == null || player.position == _selectedPosition;
      
      if (widget.hideMarkedToday && _isSameDay(player.lastAttendance, DateTime.now())) {
        return false;
      }
      
      return matchesSearch && matchesPosition;
    }).toList();

    return Column(
      children: [
        // --- AQUÍ ESTÁN LOS INDICADORES QUE FALTABAN ---
        AttendanceInsightsBar(allPlayers: _allPlayers),
        
        const SizedBox(height: 16),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar jugador...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildPositionFilter(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh ?? () async => _loadData(),
            child: filteredPlayers.isEmpty
                ? const Center(child: Text('No se encontraron jugadores'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredPlayers.length,
                    itemBuilder: (context, index) => _buildPlayerCard(filteredPlayers[index]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPositionFilter() {
    final positions = ['POR', 'DEF', 'MED', 'DEL'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: _selectedPosition,
        hint: const Text('Pos', style: TextStyle(color: Colors.grey)),
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF1E1E1E),
        items: [
          const DropdownMenuItem(value: null, child: Text('Todas')),
          ...positions.map((p) => DropdownMenuItem(value: p, child: Text(p))),
        ],
        onChanged: (val) => setState(() => _selectedPosition = val),
      ),
    );
  }

  Widget _buildPlayerCard(Player player) {
    final markedToday = _isSameDay(player.lastAttendance, DateTime.now());

    return Card(
      elevation: 0,
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.2),
          child: Text(
            player.position[0],
            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        title: Text('${player.firstName} ${player.lastName}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Sesiones: ${player.sessionsCompleted}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                markedToday ? Icons.check_circle : Icons.radio_button_unchecked,
                color: markedToday ? Colors.green : Colors.white24,
                size: 28,
              ),
              onPressed: markedToday ? null : () => _incrementAttendance(player),
            ),
            if (widget.showControls)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PlayerFormScreen(player: player)),
                ).then((_) => widget.onRefresh?.call()),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerProfileScreen(player: player),
            ),
          ).then((_) => widget.onRefresh?.call());
        },
      ),
    );
  }
}
