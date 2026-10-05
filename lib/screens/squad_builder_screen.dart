import 'package:flutter/material.dart';
import '../models/player_model.dart';
import '../models/match_roster_player.dart';
import '../services/storage_service.dart';
import '../services/team_balancer.dart';

class SquadBuilderScreen extends StatefulWidget {
  final Function(List<MatchRosterPlayer> home, List<MatchRosterPlayer> away)? onSendToScoreboard;

  const SquadBuilderScreen({super.key, this.onSendToScoreboard});

  @override
  State<SquadBuilderScreen> createState() => _SquadBuilderScreenState();
}

class _SquadBuilderScreenState extends State<SquadBuilderScreen> {
  List<PlayerModel> _allPlayers = [];
  final Set<String> _selectedIds = {};
  MatchTeams? _generatedTeams;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final list = await StorageService.loadPlayers();
    setState(() {
      _allPlayers = list;
      _isLoading = false;
    });
  }

  void _generate() {
    final selected = _allPlayers.where((p) => _selectedIds.contains(p.id)).toList();
    if (selected.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno 2 giocatori per generare le squadre.')),
      );
      return;
    }

    setState(() {
      _generatedTeams = TeamBalancer.balanceTeams(selected);
    });
  }

  void _swapPlayer(PlayerModel player, int fromTeam) {
    if (_generatedTeams == null) return;
    setState(() {
      if (fromTeam == 1) {
        _generatedTeams!.team1.removeWhere((p) => p.id == player.id);
        _generatedTeams!.team2.add(player);
      } else {
        _generatedTeams!.team2.removeWhere((p) => p.id == player.id);
        _generatedTeams!.team1.add(player);
      }
    });
  }

  void _sendToScoreboard() {
    if (_generatedTeams == null || widget.onSendToScoreboard == null) return;

    final homeRoster = <MatchRosterPlayer>[];
    for (var i = 0; i < _generatedTeams!.team1.length; i++) {
      final p = _generatedTeams!.team1[i];
      homeRoster.add(MatchRosterPlayer(
        dbId: p.id,
        num: '${i + 1}',
        name: p.name,
        inField: true,
        isGK: p.role == PlayerRole.POR,
      ));
    }

    final awayRoster = <MatchRosterPlayer>[];
    for (var i = 0; i < _generatedTeams!.team2.length; i++) {
      final p = _generatedTeams!.team2[i];
      awayRoster.add(MatchRosterPlayer(
        dbId: p.id,
        num: '${i + 1}',
        name: p.name,
        inField: true,
        isGK: p.role == PlayerRole.POR,
      ));
    }

    widget.onSendToScoreboard!(homeRoster, awayRoster);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Squadre caricate nello Scoreboard Live!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Box Contatore Convocati + Tasto Azzera
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt_outlined, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 8),
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Convocati: ',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: '${_selectedIds.length}',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_selectedIds.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedIds.clear()),
                    icon: const Icon(Icons.clear_all, size: 16, color: Color(0xFFEF4444)),
                    label: const Text(
                      'Azzera',
                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tasto Genera Squadre
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.flash_on, color: Color(0xFF042F22)),
              label: const Text('GENERA SQUADRE BILANCIATE', style: TextStyle(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: const Color(0xFF042F22),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Risultato Squadre se già generate
          if (_generatedTeams != null) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SQUADRE GENERATE',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: _sendToScoreboard,
                  icon: const Icon(Icons.sports_soccer, size: 16),
                  label: const Text('Carica su Match'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Squadra 1
                Expanded(
                  child: _buildTeamCard(
                    title: 'Squadra 1',
                    team: _generatedTeams!.team1,
                    avgOvr: _generatedTeams!.avgOvr1,
                    teamColor: const Color(0xFF3B82F6),
                    fromTeamIdx: 1,
                  ),
                ),
                const SizedBox(width: 10),
                // Squadra 2
                Expanded(
                  child: _buildTeamCard(
                    title: 'Squadra 2',
                    team: _generatedTeams!.team2,
                    avgOvr: _generatedTeams!.avgOvr2,
                    teamColor: const Color(0xFFEF4444),
                    fromTeamIdx: 2,
                  ),
                ),
              ],
            ),
          ],

          const Divider(color: Color(0xFF1E293B), height: 32),

          const Text(
            'Tocca un atleta per convocarlo o escluderlo:',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          // Lista selezionabili
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _allPlayers.length,
            itemBuilder: (ctx, i) {
              final p = _allPlayers[i];
              final isSelected = _selectedIds.contains(p.id);
              final ovr = p.ovrData;

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedIds.remove(p.id);
                    } else {
                      _selectedIds.add(p.id);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.08) : const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF475569),
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 16, color: Color(0xFF042F22))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                            Row(
                              children: [
                                Text(
                                  p.role.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: p.roleColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Grado ${ovr.letter} (${ovr.numeric})',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard({
    required String title,
    required List<PlayerModel> team,
    required double avgOvr,
    required Color teamColor,
    required int fromTeamIdx,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: teamColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: teamColor),
          ),
          Text(
            'OVR Medio: ${avgOvr.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...team.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Text(
                      p.role.name,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: p.roleColor),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => _swapPlayer(p, fromTeamIdx),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(Icons.swap_horiz, size: 16, color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}