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
  String _sortBy = 'ovr_desc';

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

  int _getRolePriority(PlayerRole role) {
    switch (role) {
      case PlayerRole.POR:
        return 0;
      case PlayerRole.DIF:
        return 1;
      case PlayerRole.CEN:
        return 2;
      case PlayerRole.ATT:
        return 3;
    }
  }

  void _sortRoster(List<TeamPlayerEntry> roster) {
    roster.sort((a, b) {
      // 1. Prima Titolari (true) poi Riserve (false)
      if (a.isStarter != b.isStarter) {
        return a.isStarter ? -1 : 1;
      }

      // 2. Ordinamento per Ruolo: POR -> DIF -> CEN -> ATT
      final pA = _dbPlayers.firstWhere((p) => p.id == a.playerId, orElse: () => PlayerModel(id: '', name: '', role: PlayerRole.CEN, stats: {}));
      final pB = _dbPlayers.firstWhere((p) => p.id == b.playerId, orElse: () => PlayerModel(id: '', name: '', role: PlayerRole.CEN, stats: {}));

      final roleCmp = _getRolePriority(pA.role).compareTo(_getRolePriority(pB.role));
      if (roleCmp != 0) return roleCmp;

      // 3. A parità di ruolo, per OVR decrescente
      return pB.ovrData.numeric.compareTo(pA.ovrData.numeric);
    });
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
      if (_sortBy == 'name_asc') return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (_sortBy == 'name_desc') return b.name.toLowerCase().compareTo(a.name.toLowerCase());
      final ovrA = _calculateStartersOvr(a);
      final ovrB = _calculateStartersOvr(b);
      if (_sortBy == 'ovr_desc') return ovrB.compareTo(ovrA);
      return ovrA.compareTo(ovrB);
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
        _selectedAway = team;
      }
    });
  }

  List<MatchRosterPlayer> _convertToRoster(TeamModel team) {
    final List<MatchRosterPlayer> roster = [];
    final sortedEntries = List<TeamPlayerEntry>.from(team.roster);
    _sortRoster(sortedEntries);

    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final dbP = _dbPlayers.firstWhere(
        (p) => p.id == entry.playerId,
        orElse: () => PlayerModel(id: entry.playerId, name: 'Giocatore', role: PlayerRole.CEN, stats: {}),
      );

      final shirtNumber = (entry.customNum != null && entry.customNum!.trim().isNotEmpty)
          ? entry.customNum!.trim()
          : '${i + 1}';

      roster.add(MatchRosterPlayer(
        dbId: dbP.id,
        num: shirtNumber,
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
        ? List.from(existing.roster.map((e) => TeamPlayerEntry(playerId: e.playerId, isStarter: e.isStarter, customNum: e.customNum)))
        : [];

    _sortRoster(currentRoster);

    String playerSearchQuery = '';
    String selectedRoleFilter = 'ALL';
    String playerSort = 'ovr_desc';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) {
          final selectedPlayerIds = currentRoster.map((e) => e.playerId).toSet();

          final availablePlayers = _dbPlayers.where((p) {
            final matchName = p.name.toLowerCase().contains(playerSearchQuery.toLowerCase());
            final matchRole = selectedRoleFilter == 'ALL' || p.role.name == selectedRoleFilter;
            return matchName && matchRole;
          }).toList();

          availablePlayers.sort((a, b) {
            if (playerSort == 'name_asc') return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            if (playerSort == 'name_desc') return b.name.toLowerCase().compareTo(a.name.toLowerCase());
            if (playerSort == 'ovr_desc') return b.ovrData.numeric.compareTo(a.ovrData.numeric);
            return a.ovrData.numeric.compareTo(b.ovrData.numeric);
          });

          return Padding(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.92,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existing == null ? 'Nuova Squadra' : 'Modifica Squadra',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // NOME E COLORE
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Nome Squadra',
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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

                  const SizedBox(height: 8),

                  // 1. BOX ROSA SQUADRA (CAPIENTE FINO A 11 GIOCATORI SENZA SCROLL)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(selectedColorVal).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(selectedColorVal), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ROSA SQUADRA (${currentRoster.length})',
                              style: TextStyle(
                                color: Color(selectedColorVal),
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '${currentRoster.where((r) => r.isStarter).length} Titolari (IN)',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 230, // OSPITA COMODAMENTE 11 GIOCATORI
                          child: currentRoster.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Center(
                                    child: Text(
                                      'Nessun giocatore in rosa.\nAggiungili selezionandoli sotto.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: currentRoster.length,
                                  itemBuilder: (c, idx) {
                                    final entry = currentRoster[idx];
                                    final p = _dbPlayers.firstWhere(
                                      (x) => x.id == entry.playerId,
                                      orElse: () => PlayerModel(id: entry.playerId, name: 'Giocatore', role: PlayerRole.CEN, stats: {}),
                                    );

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: entry.isStarter ? const Color(0xFF10B981) : const Color(0xFF334155),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // NUMERO DI MAGLIA MODIFICABILE
                                          SizedBox(
                                            width: 28,
                                            height: 24,
                                            child: TextFormField(
                                              initialValue: entry.customNum ?? '${idx + 1}',
                                              keyboardType: TextInputType.number,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                              decoration: InputDecoration(
                                                contentPadding: EdgeInsets.zero,
                                                filled: true,
                                                fillColor: const Color(0xFF0F172A),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                                              ),
                                              onChanged: (val) {
                                                entry.customNum = val.trim();
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 6),

                                          // BADGE RUOLO COLORATO
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: p.roleColor.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: p.roleColor.withValues(alpha: 0.6), width: 1),
                                            ),
                                            child: Text(
                                              p.role.name,
                                              style: TextStyle(color: p.roleColor, fontWeight: FontWeight.w900, fontSize: 10),
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // NOME E OVR
                                          Expanded(
                                            child: Text(
                                              '${p.name} • ${p.ovrData.numeric}',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),

                                          // TOGGLE TITOLARE (IN / OUT) CON RE-ORDINAMENTO
                                          InkWell(
                                            onTap: () {
                                              setMState(() {
                                                entry.isStarter = !entry.isStarter;
                                                _sortRoster(currentRoster);
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: entry.isStarter ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFF334155),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: entry.isStarter ? const Color(0xFF10B981) : Colors.transparent),
                                              ),
                                              child: Text(
                                                entry.isStarter ? 'IN' : 'OUT',
                                                style: TextStyle(
                                                  color: entry.isStarter ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),

                                          // TASTO RIMUOVI
                                          InkWell(
                                            onTap: () {
                                              setMState(() {
                                                currentRoster.removeAt(idx);
                                                _sortRoster(currentRoster);
                                              });
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 2. CERCA E FILTRI GIOCATORI DISPONIBILI
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setMState(() => playerSearchQuery = val),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Cerca per aggiungere...',
                            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 16),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
                        child: DropdownButton<String>(
                          value: playerSort,
                          dropdownColor: const Color(0xFF1E293B),
                          underline: const SizedBox(),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                          items: const [
                            DropdownMenuItem(value: 'ovr_desc', child: Text('OVR ↓')),
                            DropdownMenuItem(value: 'ovr_asc', child: Text('OVR ↑')),
                            DropdownMenuItem(value: 'name_asc', child: Text('A-Z')),
                            DropdownMenuItem(value: 'name_desc', child: Text('Z-A')),
                          ],
                          onChanged: (v) {
                            if (v != null) setMState(() => playerSort = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // CHIP FILTRO RUOLI RAPIDI
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['ALL', 'POR', 'DIF', 'CEN', 'ATT'].map((role) {
                        final active = selectedRoleFilter == role;
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: InkWell(
                            onTap: () => setMState(() => selectedRoleFilter = role),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: active ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                role,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: active ? const Color(0xFF042F22) : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // LISTA DISPONIBILI DAL DATABASE
                  Expanded(
                    child: ListView.builder(
                      itemCount: availablePlayers.length,
                      itemBuilder: (c, idx) {
                        final p = availablePlayers[idx];
                        final isAlreadyInTeam = selectedPlayerIds.contains(p.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAlreadyInTeam ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: p.roleColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(p.role.name, style: TextStyle(color: p.roleColor, fontWeight: FontWeight.bold, fontSize: 9)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${p.name} • OVR ${p.ovrData.numeric}',
                                  style: TextStyle(
                                    color: isAlreadyInTeam ? Colors.white54 : Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (!isAlreadyInTeam)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    setMState(() {
                                      currentRoster.add(TeamPlayerEntry(playerId: p.id, isStarter: true));
                                      _sortRoster(currentRoster);
                                    });
                                  },
                                  child: const Text('+ Aggiungi', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),
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

                            _sortRoster(currentRoster);
                            final newTeam = TeamModel(
                              id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                              name: name,
                              colorValue: selectedColorVal,
                              roster: currentRoster,
                            );

                            await StorageService.saveSingleTeam(newTeam);
                            if (ctx.mounted) Navigator.pop(ctx);
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
            // BARRA RICERCA ED ORDINAMENTO SQUADRE
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
                      DropdownMenuItem(value: 'name_desc', child: Text('Nome Z-A')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _sortBy = v);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // BANNER CASA VS OSPITI + TASTO BLU CON PALLONE
            if (_selectedHome != null || _selectedAway != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedHome != null ? '🏠 CASA: ${_selectedHome!.name} (${_calculateStartersOvr(_selectedHome!)})' : 'Seleziona CASA',
                            style: TextStyle(
                              color: _selectedHome != null ? Color(_selectedHome!.colorValue) : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                        Expanded(
                          child: Text(
                            _selectedAway != null ? '🚗 OSPITI: ${_selectedAway!.name} (${_calculateStartersOvr(_selectedAway!)})' : 'Seleziona OSPITI',
                            style: TextStyle(
                              color: _selectedAway != null ? Color(_selectedAway!.colorValue) : const Color(0xFF94A3B8),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // TASTO DESELEZIONA RAPIDO
                        InkWell(
                          onTap: () => setState(() {
                            _selectedHome = null;
                            _selectedAway = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.close, size: 15, color: Color(0xFFEF4444)),
                          ),
                        ),
                      ],
                    ),
                    if (canLaunchMatch) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _dispatchToMatch,
                          icon: const Icon(Icons.sports_soccer, size: 18),
                          label: const Text('CARICA SU MATCH', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // ELENCO DELLE SQUADRE CREATE
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
                                // SOSTITUISCI L'ICONBUTTON DELETE CON QUESTO CON CONFERMA:
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 18),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (dCtx) => AlertDialog(
                                        backgroundColor: const Color(0xFF1E293B),
                                        title: const Text('Conferma eliminazione', style: TextStyle(color: Colors.white)),
                                        content: Text('Vuoi davvero eliminare la squadra "${team.name}"?', style: const TextStyle(color: Color(0xFF94A3B8))),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dCtx),
                                            child: const Text('Annulla', style: TextStyle(color: Color(0xFF94A3B8))),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                            onPressed: () async {
                                              Navigator.pop(dCtx);
                                              await StorageService.deleteTeam(team.id);
                                              if (_selectedHome?.id == team.id) _selectedHome = null;
                                              if (_selectedAway?.id == team.id) _selectedAway = null;
                                              _loadData();
                                            },
                                            child: const Text('Elimina', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
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

            // TASTO IN BASSO: CREA SQUADRA
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF334155)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _openTeamEditor(),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text('Nuova Squadra', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}