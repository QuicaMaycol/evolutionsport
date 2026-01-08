import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player.dart';
import '../screens/player_form_screen.dart';

class PlayerList extends StatefulWidget {
  final Future<List<Player>> playersFuture;
  final Future<void> Function()? onRefresh;
  final bool showControls;
  final bool hideMarkedToday;
  final Future<String>? userRoleFuture; // Optional, defaults to coach if null

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
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('${player.firstName} marcado como presente'),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _navigateToForm({Player? player}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlayerFormScreen(player: player)),
    );

    if (result == true && widget.onRefresh != null) {
      await widget.onRefresh!();
      await _loadData();
    }
  }

  List<Player> get _filteredPlayers {
    return _allPlayers.where((player) {
      final matchesName = player.fullName
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
      final matchesPosition = _selectedPosition == null ||
          _selectedPosition == 'Todos' ||
          player.position == _selectedPosition;

      final hasAttendedToday =
          _isSameDay(player.lastAttendance, DateTime.now());
      if (widget.hideMarkedToday && hasAttendedToday) {
        return false;
      }

      return matchesName && matchesPosition;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text('Error: $_errorMessage'));
    }

    final filteredList = _filteredPlayers;

    Widget content = Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.showControls
          ? FutureBuilder<String>(
              future: widget.userRoleFuture,
              builder: (context, snapshot) {
                // Only show FAB if role is ADMIN
                if (snapshot.hasData && snapshot.data == 'admin') {
                  return FloatingActionButton(
                    onPressed: () => _navigateToForm(),
                    backgroundColor: const Color(0xFF4CAF50),
                    elevation: 4,
                    child: const Icon(Icons.add, color: Colors.white),
                  );
                }
                return const SizedBox.shrink();
              },
            )
          : null,
      body: Column(
        children: [
          if (widget.showControls)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Buscar jugador...',
                          hintStyle: TextStyle(color: Colors.white38),
                          prefixIcon: Icon(Icons.search, color: Colors.white38),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPosition,
                        hint: const Text("Posición", style: TextStyle(color: Colors.white38)),
                        dropdownColor: const Color(0xFF2A2A2A),
                        icon: const Icon(Icons.filter_list, color: Colors.white38),
                        items: <String>[
                          'Todos',
                          'Portero',
                          'Defensa',
                          'Medio',
                          'Delantero',
                        ].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedPosition = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 64, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'Todo listo por hoy',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final player = filteredList[index];
                      final hasAttendedToday =
                          _isSameDay(player.lastAttendance, DateTime.now());
                      
                      return FutureBuilder<String>(
                        future: widget.userRoleFuture,
                        builder: (context, roleSnapshot) {
                          final isAdmin = roleSnapshot.data == 'admin';
                          final canEdit = widget.showControls && isAdmin;

                          return GestureDetector(
                            onTap: canEdit
                                ? () => _navigateToForm(player: player)
                                : null,
                                child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    // Avatar with Status Ring
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4CAF50).withOpacity(0.2),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF4CAF50).withOpacity(0.5),
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          player.firstName.isNotEmpty
                                              ? player.firstName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Color(0xFF4CAF50),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Player Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            player.fullName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.05),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              player.position.toUpperCase(),
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.5),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Action Button
                                    if (hasAttendedToday)
                                      _StatusBadge(label: 'Presente', color: const Color(0xFF4CAF50))
                                    else
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _incrementAttendance(player),
                                          borderRadius: BorderRadius.circular(30),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 10),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF4CAF50),
                                                  Color(0xFF66BB6A)
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF4CAF50)
                                                      .withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(Icons.check,
                                                    color: Colors.white, size: 16),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Asistió',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (widget.onRefresh != null) {
      return RefreshIndicator(
        onRefresh: () async {
          await widget.onRefresh!();
          await _loadData();
        },
        child: content,
      );
    }
    return content;
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
