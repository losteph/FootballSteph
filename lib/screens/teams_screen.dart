import 'package:flutter/material.dart';
import '../models/team_model.dart';
import '../models/player_model.dart';
import '../models/match_roster_player.dart';
import '../services/storage_service.dart';

class TeamsScreen extends StatefulWidget {
  final Function(
    List<MatchRosterPlayer> homeRoster,
    List<MatchRosterPlayer> awayRoster,
    String homeName,
    String awayName,
    Color homeColor,
    Color awayColor,
  )? onLoadMatch;

  const TeamsScreen({super.key, this.onLoadMatch});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  List<TeamModel> _teams = [];
  List<PlayerModel> _dbPlayers = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _sortBy = 'ovr_desc'; // 'ovr_desc', 'ovr_asc', 'name_asc'

  // Selezione per match: max 2 squadre
  TeamModel? _selectedHome;
  TeamModel? _selectedAway;

  final Map<String, Color> _teamColors = const {
    '🔵 Blu': Color(0xFF3B82F6),
    '🔴 Rosso': Color(0xFFEF4444),
    '🟢 Verde': Color(0xFF10B981),
    '🟡 Giallo': Color(0xFFEAB308),
    '🟠 Arancio': Color(0xFFF97316),
    '🟣 Viola': Color(0xFF8B5CF6),
    '⚫ Nero': Color(0xFF1E293B),
    '⚪ Bianco': Color(0xFFF8FAFC),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final teams = await StorageService.loadTeams();
    final players = await StorageService.loadPlayers();
    if (mounted) {
      setState(() {
        _teams = teams;
        _dbPlayers = players;
        _isLoading = false;
      });
    }
  }

  double _calculateStartersOvr(TeamModel team) {
    final starterIds = team.roster.where((r) => r.isStarter).map((r) => r.playerId).toSet();
    final starters = _dbPlayers.where((p) => starterIds.contains(p.id)).toList();
    if (starters.isEmpty) return 0.0;
    final total = starters.fold<double>(0.0, (acc, p) => acc + p.ovrData.numeric);
    return double.parse((total / starters.length).toStringAsFixed(1));
  }

  List<TeamModel> _getFilteredTeams() {
    var list = _teams.where((t) {
      return t.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    list.sort((a, b) {
      if (_sortBy == 'name_asc') {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      final ovrA = _calculateStartersOvr(a);
      final ovrB = _calculateStartersOvr(b);
      if (_sortBy == 'ovr_desc') {
        return ovrB.compareTo(ovrA);
      } else {
        return ovrA.compareTo(ovrB);
      }
    });

    return list;
  }

  void _toggleTeamSelection(TeamModel team) {
    setState(() {
      if (_selectedHome?.id == team.id) {
        _selectedHome = null;
      } else if (_selectedAway?.id == team.id) {
        _selectedAway = null;
      } else if (_selectedHome == null) {
        _selectedHome = team;
      } else if (_selectedAway == null) {
        _selectedAway = team;
      } else {
        // Se entrambe piene, sostituisce la seconda
        _selectedAway = team;
      }
    });
  }

  List<MatchRosterPlayer> _convertToRoster(TeamModel team) {
    final List<MatchRosterPlayer> roster = [];
    for (int i = 0; i < team.roster.length; i++) {
      final entry = team.roster[i];
      final dbP = _dbPlayers.firstWhere(
        (p) => p.id == entry.playerId,
        orElse: () => PlayerModel(id: entry.playerId, name: 'Giocatore', role: PlayerRole.CEN, stats: {}),
      );

      roster.add(MatchRosterPlayer(
        dbId: dbP.id,
        num: '${i + 1}',
        name: dbP.name,
        inField: entry.isStarter,
        isGK: i == 0 && entry.isStarter && dbP.role == PlayerRole.POR,
      ));
    }
    return roster;
  }

  void _dispatchToMatch() {
    if (_selectedHome == null || _selectedAway == null) return;

    final homeRoster = _convertToRoster(_selectedHome!);
    final awayRoster = _convertToRoster(_selectedAway!);

    widget.onLoadMatch?.call(
      homeRoster,
      awayRoster,
      _selectedHome!.name,
      _selectedAway!.name,
      Color(_selectedHome!.colorValue),
      Color(_selectedAway!.colorValue),
    );
  }

  void _openTeamEditor([TeamModel? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    int selectedColorVal = existing?.colorValue ?? _teamColors.values.first.toARGB32();
    List<TeamPlayerEntry> currentRoster = existing != null
        ? List.from(existing.roster.map((e) => TeamPlayerEntry(playerId: e.playerId, isStarter: e.isStarter)))
        : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) {
          final selectedPlayerIds = currentRoster.map((e) => e.playerId).toSet();

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.85,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existing == null ? 'Nuova Squadra' : 'Modifica Squadra',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),

                  // Nome e Colore
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Nome Squadra',
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<int>(
                        value: selectedColorVal,
                        dropdownColor: const Color(0xFF1E293B),
                        items: _teamColors.entries.map((e) {
                          return DropdownMenuItem<int>(
                            value: e.value.toARGB32(),
                            child: Row(
                              children: [
                                Icon(Icons.circle, color: e.value, size: 16),
                                const SizedBox(width: 6),
                                Text(e.key.split(' ')[1], style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setMState(() => selectedColorVal = val);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Text('Giocatori in Rosa (Spunta chi è TITOLARE):', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // Lista Giocatori con Checkbox Titolare
                  Expanded(
                    child: ListView.builder(
                      itemCount: _dbPlayers.length,
                      itemBuilder: (c, idx) {
                        final p = _dbPlayers[idx];
                        final isIncluded = selectedPlayerIds.contains(p.id);
                        final entry = isIncluded ? currentRoster.firstWhere((r) => r.playerId == p.id) : null;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isIncluded ? const Color(0xFF1E293B) : const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isIncluded ? const Color(0xFF334155) : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Checkbox(
                                value: isIncluded,
                                activeColor: const Color(0xFF10B981),
                                onChanged: (val) {
                                  setMState(() {
                                    if (val == true) {
                                      currentRoster.add(TeamPlayerEntry(playerId: p.id, isStarter: true));
                                    } else {
                                      currentRoster.removeWhere((r) => r.playerId == p.id);
                                    }
                                  });
                                },
                              ),
                              Expanded(
                                child: Text(
                                  '${p.name} (${p.role.name}) - OVR ${p.ovrData.numeric}',
                                  style: TextStyle(color: isIncluded ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              if (isIncluded)
                                InkWell(
                                  onTap: () {
                                    setMState(() {
                                      entry.isStarter = !entry.isStarter;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: entry!.isStarter ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFF334155),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: entry.isStarter ? const Color(0xFF10B981) : Colors.transparent),
                                    ),
                                    child: Text(
                                      entry.isStarter ? 'TITOLARE' : 'PANCHINA',
                                      style: TextStyle(
                                        color: entry.isStarter ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF334155))),
                          child: const Text('Annulla', style: TextStyle(color: Color(0xFF94A3B8))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: const Color(0xFF042F22)),
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;

                            final newTeam = TeamModel(
                              id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                              name: name,
                              colorValue: selectedColorVal,
                              roster: currentRoster,
                            );

                            await StorageService.saveSingleTeam(newTeam);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            _loadData();
                          },
                          child: const Text('Salva Squadra', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }

    final filteredTeams = _getFilteredTeams();
    final canLaunchMatch = _selectedHome != null && _selectedAway != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Barra Ricerca e Ordinamento
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cerca squadra...',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 18),
                      filled: true,
                      fillColor: const Color(0xFF111827),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1E293B))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1E293B))),
                  child: DropdownButton<String>(
                    value: _sortBy,
                    dropdownColor: const Color(0xFF1E293B),
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: const [
                      DropdownMenuItem(value: 'ovr_desc', child: Text('OVR Decrescente')),
                      DropdownMenuItem(value: 'ovr_asc', child: Text('OVR Crescente')),
                      DropdownMenuItem(value: 'name_asc', child: Text('Nome A-Z')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _sortBy = v);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Banner Selezione Partita (Se ci sono squadre selezionate)
            if (_selectedHome != null || _selectedAway != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF334155))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedHome != null ? '🏠 CASA: ${_selectedHome!.name} (${_calculateStartersOvr(_selectedHome!)})' : 'Seleziona CASA',
                        style: TextStyle(color: _selectedHome != null ? Color(_selectedHome!.colorValue) : const Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))),
                    Expanded(
                      child: Text(
                        _selectedAway != null ? '🚗 OSPITI: ${_selectedAway!.name} (${_calculateStartersOvr(_selectedAway!)})' : 'Seleziona OSPITI',
                        style: TextStyle(color: _selectedAway != null ? Color(_selectedAway!.colorValue) : const Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Elenco Squadre
            Expanded(
              child: filteredTeams.isEmpty
                  ? const Center(child: Text('Nessuna squadra trovata. Creane una con il tasto +', style: TextStyle(color: Color(0xFF64748B))))
                  : ListView.builder(
                      itemCount: filteredTeams.length,
                      itemBuilder: (ctx, i) {
                        final team = filteredTeams[i];
                        final startersOvr = _calculateStartersOvr(team);
                        final startersCount = team.roster.where((r) => r.isStarter).length;
                        final benchCount = team.roster.length - startersCount;

                        final isHome = _selectedHome?.id == team.id;
                        final isAway = _selectedAway?.id == team.id;
                        final isSelected = isHome || isAway;

                        return InkWell(
                          onTap: () => _toggleTeamSelection(team),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? (isHome ? const Color(0xFF10B981) : const Color(0xFF3B82F6)) : const Color(0xFF1E293B),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 40,
                                  decoration: BoxDecoration(color: Color(team.colorValue), borderRadius: BorderRadius.circular(4)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(team.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                          if (isHome) const Text(' [CASA]', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
                                          if (isAway) const Text(' [OSPITI]', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 11)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$startersCount Titolari • $benchCount Riserve',
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(6)),
                                  child: Text('OVR $startersOvr', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 13)),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Color(0xFF64748B), size: 18),
                                  onPressed: () => _openTeamEditor(team),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 18),
                                  onPressed: () async {
                                    await StorageService.deleteTeam(team.id);
                                    if (_selectedHome?.id == team.id) _selectedHome = null;
                                    if (_selectedAway?.id == team.id) _selectedAway = null;
                                    _loadData();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 10),

            // Tasti Azione Inferiori: Crea Squadra & Carica su Match
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _openTeamEditor(),
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text('Nuova Squadra', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (canLaunchMatch) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: const Color(0xFF042F22),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _dispatchToMatch,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('CARICA SU MATCH', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}