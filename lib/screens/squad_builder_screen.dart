import 'package:flutter/material.dart';
import '../models/player_model.dart';
import '../models/match_roster_player.dart';
import '../services/storage_service.dart';
import '../services/team_balancer.dart';

class SquadBuilderScreen extends StatefulWidget {
  final Function(List<MatchRosterPlayer> home, List<MatchRosterPlayer> away)? onSendToScoreboard;

  const SquadBuilderScreen({super.key, this.onSendToScoreboard});

  @override
  State<SquadBuilderScreen> createState() => SquadBuilderScreenState();
}

class SquadBuilderScreenState extends State<SquadBuilderScreen> {
  List<PlayerModel> _allPlayers = [];
  MatchTeams _generatedTeams = MatchTeams(team1: [], team2: []);
  int _targetTeam = 1; // 1 = Squadra 1 (Casa), 2 = Squadra 2 (Ospiti)
  bool _isLoading = true;

  String _searchQuery = '';
  String _roleFilter = 'ALL';
  String _sortBy = 'ovr-desc';
  final TextEditingController _searchController = TextEditingController();

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

  void reload() {
    _loadPlayers();
  }

  List<PlayerModel> get _filteredPlayers {
    var result = List<PlayerModel>.from(_allPlayers);

    if (_searchQuery.trim().isNotEmpty) {
      result = result
          .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_roleFilter != 'ALL') {
      result = result.where((p) => p.role.name == _roleFilter).toList();
    }

    result.sort((a, b) {
      switch (_sortBy) {
        case 'ovr-desc':
          return b.ovrData.numeric.compareTo(a.ovrData.numeric);
        case 'ovr-asc':
          return a.ovrData.numeric.compareTo(b.ovrData.numeric);
        case 'name-asc':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'name-desc':
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        default:
          return 0;
      }
    });

    return result;
  }

  int get _totalSelectedCount => _generatedTeams.team1.length + _generatedTeams.team2.length;

  void _onPlayerTapped(PlayerModel p) {
    setState(() {
      final inT1 = _generatedTeams.team1.any((x) => x.id == p.id);
      final inT2 = _generatedTeams.team2.any((x) => x.id == p.id);

      if (inT1) {
        _generatedTeams.team1.removeWhere((x) => x.id == p.id);
      } else if (inT2) {
        _generatedTeams.team2.removeWhere((x) => x.id == p.id);
      } else {
        if (_targetTeam == 1) {
          _generatedTeams.team1.add(p);
        } else {
          _generatedTeams.team2.add(p);
        }
      }
    });
  }

  void _generateAutomatic() {
    final allAssigned = [..._generatedTeams.team1, ..._generatedTeams.team2];
    if (allAssigned.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno 2 giocatori da bilanciare.')),
      );
      return;
    }

    setState(() {
      _generatedTeams = TeamBalancer.balanceTeams(allAssigned);
    });
  }

  void _clearTeams() {
    setState(() {
      _generatedTeams = MatchTeams(team1: [], team2: []);
    });
  }

  void _swapPlayer(PlayerModel player, int fromTeam) {
    setState(() {
      if (fromTeam == 1) {
        _generatedTeams.team1.removeWhere((p) => p.id == player.id);
        _generatedTeams.team2.add(player);
      } else {
        _generatedTeams.team2.removeWhere((p) => p.id == player.id);
        _generatedTeams.team1.add(player);
      }
    });
  }

  void _sendToScoreboard() {
    if (widget.onSendToScoreboard == null) return;
    if (_generatedTeams.team1.isEmpty && _generatedTeams.team2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci almeno un giocatore per squadra.')),
      );
      return;
    }

    final homeRoster = <MatchRosterPlayer>[];
    for (var i = 0; i < _generatedTeams.team1.length; i++) {
      final p = _generatedTeams.team1[i];
      homeRoster.add(MatchRosterPlayer(
        dbId: p.id,
        num: '${i + 1}',
        name: p.name,
        inField: true,
        isGK: p.role == PlayerRole.POR,
      ));
    }

    final awayRoster = <MatchRosterPlayer>[];
    for (var i = 0; i < _generatedTeams.team2.length; i++) {
      final p = _generatedTeams.team2[i];
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

    final displayList = _filteredPlayers;

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
                            text: 'Convocati totali: ',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: '$_totalSelectedCount',
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
                if (_totalSelectedCount > 0)
                  TextButton.icon(
                    onPressed: _clearTeams,
                    icon: const Icon(Icons.clear_all, size: 16, color: Color(0xFFEF4444)),
                    label: const Text(
                      'Svuota',
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

          // Tasto Bilancia Automaticamente
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateAutomatic,
              icon: const Icon(Icons.flash_on, color: Color(0xFF042F22)),
              label: const Text('BILANCIA AUTOMATICAMENTE', style: TextStyle(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: const Color(0xFF042F22),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Intestazione con pulsante Carica
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SCHIERAMENTO SQUADRE',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              if (_totalSelectedCount > 0)
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
          const SizedBox(height: 10),

          // I Due Box Squadra (Toccabili invisibilmente per impostare la destinazione)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _targetTeam = 1),
                  child: _buildTeamCard(
                    title: 'Squadra 1',
                    team: _generatedTeams.team1,
                    avgOvr: _generatedTeams.avgOvr1,
                    teamColor: const Color(0xFF3B82F6),
                    fromTeamIdx: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _targetTeam = 2),
                  child: _buildTeamCard(
                    title: 'Squadra 2',
                    team: _generatedTeams.team2,
                    avgOvr: _generatedTeams.avgOvr2,
                    teamColor: const Color(0xFFEF4444),
                    fromTeamIdx: 2,
                  ),
                ),
              ),
            ],
          ),

          const Divider(color: Color(0xFF1E293B), height: 32),

          // Sezione Filtri e Ricerca
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Cerca per nome...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 18),
                    filled: true,
                    fillColor: const Color(0xFF111827),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981))),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort, color: Color(0xFF94A3B8)),
                color: const Color(0xFF1E293B),
                onSelected: (val) => setState(() => _sortBy = val),
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'ovr-desc', child: Text('OVR Decrescente', style: TextStyle(color: Colors.white, fontSize: 13))),
                  PopupMenuItem(value: 'ovr-asc', child: Text('OVR Crescente', style: TextStyle(color: Colors.white, fontSize: 13))),
                  PopupMenuItem(value: 'name-asc', child: Text('Nome (A-Z)', style: TextStyle(color: Colors.white, fontSize: 13))),
                  PopupMenuItem(value: 'name-desc', child: Text('Nome (Z-A)', style: TextStyle(color: Colors.white, fontSize: 13))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tutti', 'ALL'),
                _buildFilterChip('🧤 POR', 'POR'),
                _buildFilterChip('🛡️ DIF', 'DIF'),
                _buildFilterChip('⚙️ CEN', 'CEN'),
                _buildFilterChip('⚡ ATT', 'ATT'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Lista atleti selezionabili
          displayList.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('Nessun atleta corrisponde ai filtri.', style: TextStyle(color: Color(0xFF94A3B8)))),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayList.length,
                  itemBuilder: (ctx, i) {
                    final p = displayList[i];
                    final inTeam1 = _generatedTeams.team1.any((x) => x.id == p.id);
                    final inTeam2 = _generatedTeams.team2.any((x) => x.id == p.id);
                    final isSelected = inTeam1 || inTeam2;
                    final ovr = p.ovrData;

                    return InkWell(
                      onTap: () => _onPlayerTapped(p),
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _roleFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _roleFilter = value),
        selectedColor: const Color(0xFF10B981),
        backgroundColor: const Color(0xFF1E293B),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF042F22) : const Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155)),
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
            'OVR Medio: ${avgOvr.isNaN || avgOvr == 0 ? '--.-' : avgOvr.toStringAsFixed(1)} (${team.length})',
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (team.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Nessun giocatore',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
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