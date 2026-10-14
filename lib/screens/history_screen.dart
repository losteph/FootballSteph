import 'package:flutter/material.dart';
import '../models/match_history_model.dart';
import '../models/player_model.dart';
import '../models/team_model.dart';
import '../models/tournament_model.dart';
import '../models/match_roster_player.dart';
import '../services/storage_service.dart';

class HistoryScreen extends StatefulWidget {
  final Function(
    List<MatchRosterPlayer> homeRoster,
    List<MatchRosterPlayer> awayRoster,
    String homeName,
    String awayName,
    Color homeColor,
    Color awayColor, [
    String? tournamentId,
  ])? onLoadTournamentMatch;

  const HistoryScreen({super.key, this.onLoadTournamentMatch});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<MatchHistoryModel> _matches = [];
  List<PlayerModel> _dbPlayers = [];
  List<TeamModel> _allTeams = [];
  List<TournamentModel> _tournaments = [];
  bool _isLoading = true;

  // 'ALL' = Globale, 'FRIENDLY' = Solo Amichevoli, oppure l'ID di un Torneo
  String _selectedViewId = 'ALL';

  // Sotto-tab attiva:
  // Per ALL/FRIENDLY: 0 = PARTITE, 1 = MARCATORI
  // Per TORNEO: 0 = CLASSIFICA, 1 = PARTITE, 2 = MARCATORI, 3 = SQUADRE
  int _activeSubTab = 0;

  TeamModel? _selectedHomeTeam;
  TeamModel? _selectedAwayTeam;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (mounted) setState(() => _isLoading = true);
    final matches = await StorageService.loadMatches();
    final players = await StorageService.loadPlayers();
    final teams = await StorageService.loadTeams();
    final tournaments = await StorageService.loadTournaments();

    if (mounted) {
      setState(() {
        _matches = matches;
        _dbPlayers = players;
        _allTeams = teams;
        _tournaments = tournaments;

        if (_selectedViewId != 'ALL' &&
            _selectedViewId != 'FRIENDLY' &&
            !_tournaments.any((t) => t.id == _selectedViewId)) {
          _selectedViewId = 'ALL';
          _activeSubTab = 0;
        }
        _isLoading = false;
      });
    }
  }

  TournamentModel? get _currentTournament {
    if (_selectedViewId == 'ALL' || _selectedViewId == 'FRIENDLY') return null;
    try {
      return _tournaments.firstWhere((t) => t.id == _selectedViewId);
    } catch (_) {
      return null;
    }
  }

  List<MatchHistoryModel> get _filteredMatches {
    if (_selectedViewId == 'ALL') return _matches;
    if (_selectedViewId == 'FRIENDLY') {
      return _matches.where((m) => m.tournamentId == null || m.tournamentId!.isEmpty).toList();
    }
    return _matches.where((m) => m.tournamentId == _selectedViewId).toList();
  }

  String _getTeamEmoji(int colorValue) {
    if (colorValue == const Color(0xFF3B82F6).toARGB32()) return '🔵';
    if (colorValue == const Color(0xFFEF4444).toARGB32()) return '🔴';
    if (colorValue == const Color(0xFF10B981).toARGB32()) return '🟢';
    if (colorValue == const Color(0xFFEAB308).toARGB32()) return '🟡';
    if (colorValue == const Color(0xFFF97316).toARGB32()) return '🟠';
    if (colorValue == const Color(0xFF8B5CF6).toARGB32()) return '🟣';
    if (colorValue == const Color(0xFF1E293B).toARGB32()) return '⚫';
    if (colorValue == const Color(0xFFF8FAFC).toARGB32()) return '⚪';
    return '⚽';
  }

  String _getPeriodHeader(String minute) {
    final m = minute.toUpperCase();
    if (m.contains('1°TS')) return '1° TEMPO SUPPLEMENTARE';
    if (m.contains('2°TS')) return '2° TEMPO SUPPLEMENTARE';
    if (m.contains('1° T') || m.contains('1°T')) return '1° TEMPO';
    if (m.contains('2° T') || m.contains('2°T')) return '2° TEMPO';
    if (m.contains('RIGOR') || m.contains('RIG')) return 'CALCI DI RIGORE';
    return '';
  }

  // --- CALCOLO CLASSIFICA CAMPIONATO ---
  List<LeagueTableRow> _calculateLeagueTable(TournamentModel tournament) {
    final Map<String, LeagueTableRow> tableMap = {};

    for (final tId in tournament.teamIds) {
      final teamObj = _allTeams.where((x) => x.id == tId).firstOrNull;
      if (teamObj != null) {
        tableMap[teamObj.name.trim().toLowerCase()] = LeagueTableRow(
          teamId: teamObj.id,
          teamName: teamObj.name,
          teamColorValue: teamObj.colorValue,
        );
      }
    }

    final tourMatches = _filteredMatches;
    for (final m in tourMatches) {
      final hKey = m.homeName.trim().toLowerCase();
      final aKey = m.awayName.trim().toLowerCase();

      tableMap.putIfAbsent(
        hKey,
        () => LeagueTableRow(teamId: hKey, teamName: m.homeName, teamColorValue: m.homeColorValue),
      );
      tableMap.putIfAbsent(
        aKey,
        () => LeagueTableRow(teamId: aKey, teamName: m.awayName, teamColorValue: m.awayColorValue),
      );

      final hRow = tableMap[hKey]!;
      final aRow = tableMap[aKey]!;

      hRow.played++;
      aRow.played++;

      hRow.goalsFor += m.homeScore;
      hRow.goalsAgainst += m.awayScore;

      aRow.goalsFor += m.awayScore;
      aRow.goalsAgainst += m.homeScore;

      if (m.homeScore > m.awayScore) {
        hRow.won++;
        aRow.lost++;
      } else if (m.awayScore > m.homeScore) {
        aRow.won++;
        hRow.lost++;
      } else {
        hRow.drawn++;
        aRow.drawn++;
      }
    }

    final rows = tableMap.values.toList();

    rows.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      if (b.goalDifference != a.goalDifference) return b.goalDifference.compareTo(a.goalDifference);
      if (b.goalsFor != a.goalsFor) return b.goalsFor.compareTo(a.goalsFor);

      int h2hA = 0;
      int h2hB = 0;
      for (final m in tourMatches) {
        final h = m.homeName.trim().toLowerCase();
        final aw = m.awayName.trim().toLowerCase();
        final nameA = a.teamName.trim().toLowerCase();
        final nameB = b.teamName.trim().toLowerCase();

        if (h == nameA && aw == nameB) {
          if (m.homeScore > m.awayScore) {
            h2hA += 3;
          } else if (m.awayScore > m.homeScore) { h2hB += 3;}
          else { h2hA += 1; h2hB += 1; }
        } else if (h == nameB && aw == nameA) {
          if (m.homeScore > m.awayScore) {
            h2hB += 3;
          } else if (m.awayScore > m.homeScore) {h2hA += 3;} 
          else { h2hA += 1; h2hB += 1; }
        }
      }
      if (h2hB != h2hA) return h2hB.compareTo(h2hA);

      return a.teamName.toLowerCase().compareTo(b.teamName.toLowerCase());
    });

    return rows;
  }

  // --- CALCOLO MARCATORI (PUNTI 4, 5 e 6) ---
  List<Map<String, dynamic>> _getScorersRanking() {
    final Map<String, Map<String, dynamic>> stats = {};
    final targetMatches = _filteredMatches;

    if (_selectedViewId == 'ALL' || _selectedViewId == 'FRIENDLY') {
      // Globale e Amichevoli: carica tutti i giocatori del DB con 0 gol iniziali
      for (var p in _dbPlayers) {
        stats[p.name] = {'name': p.name, 'goals': 0, 'assists': 0};
      }
    } else if (_currentTournament != null) {
      // Torneo specifico: carica subito a 0 gol SOLO i giocatori appartenenti alle squadre del torneo!
      final enrolledTeams = _allTeams.where((t) => _currentTournament!.teamIds.contains(t.id));
      for (final team in enrolledTeams) {
        for (final entry in team.roster) {
          final dbP = _dbPlayers.where((p) => p.id == entry.playerId).firstOrNull;
          if (dbP != null) {
            stats[dbP.name] = {'name': dbP.name, 'goals': 0, 'assists': 0};
          }
        }
      }
    }

    for (var m in targetMatches) {
      for (var e in m.events) {
        if (e.isPenalty) continue;

        if (e.type == 'GOL' || e.type == 'RIGORE_SEGNATO') {
          final pName = _getPlayerNameFromId(m, e.playerId);
          if (pName != null && stats.containsKey(pName)) {
            stats[pName]!['goals']++;
          } else if (pName != null) {
            stats[pName] = {'name': pName, 'goals': 1, 'assists': 0};
          }
        }

        if (e.type == 'GOL' && e.sub.contains('Assist:')) {
          final match = RegExp(r'Assist:\s*#\d+\s+([^•\)]+)').firstMatch(e.sub);
          if (match != null) {
            final aName = match.group(1)!.trim();
            if (stats.containsKey(aName)) {
              stats[aName]!['assists']++;
            } else {
              stats[aName] = {'name': aName, 'goals': 0, 'assists': 1};
            }
          }
        }
      }
    }

    final list = stats.values.toList();
    list.sort((a, b) {
      int cmp = (b['goals'] as int).compareTo(a['goals'] as int);
      if (cmp != 0) return cmp;
      int assCmp = (b['assists'] as int).compareTo(a['assists'] as int);
      if (assCmp != 0) return assCmp;
      return (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
    });

    return list;
  }

  String? _getPlayerNameFromId(MatchHistoryModel m, String? id) {
    if (id == null) return null;
    final allPlayers = [...m.homeRoster, ...m.awayRoster];
    try {
      return allPlayers.firstWhere((p) => p.dbId == id).name;
    } catch (_) {
      return null;
    }
  }

  // --- CONFERMA ELIMINAZIONE TORNEO (PUNTO 1) ---
  Future<bool> _confirmDeleteTournamentDialog(TournamentModel tournament) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Conferma eliminazione', style: TextStyle(color: Colors.white)),
        content: Text(
          'Vuoi davvero eliminare il torneo "${tournament.name}"?\nLe partite giocate rimarranno salvate nello storico globale.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Annulla', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Elimina', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // --- CONFERMA ELIMINAZIONE PARTITA (PUNTO 1) ---
  Future<bool> _confirmDeleteMatchDialog(MatchHistoryModel m) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Conferma eliminazione', style: TextStyle(color: Colors.white)),
        content: Text(
          'Vuoi davvero eliminare definitivamente la partita "${m.homeName} vs ${m.awayName}" (${m.homeScore}-${m.awayScore})?',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Annulla', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Elimina', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // --- CREAZIONE E MODIFICA TORNEO ---
  void _openTournamentModal([TournamentModel? existing]) async {
    // Ricarica sempre le squadre fresche prima di aprire il modale (Punto 3)
    final freshTeams = await StorageService.loadTeams();
    if (mounted) {
      setState(() => _allTeams = freshTeams);
    }
    if (!mounted) return;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final Set<String> selectedTeamIds = Set<String>.from(existing?.teamIds ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existing == null ? '🏆 Nuovo Torneo (Campionato)' : '✏️ Modifica Torneo',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nome Torneo (es. Steph League - Girone A)',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SQUADRE PARTECIPANTI:',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${selectedTeamIds.length} selezionate',
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _allTeams.isEmpty
                        ? const Center(
                            child: Text(
                              'Nessuna squadra presente.\nCreale prima nella scheda "Squadre"!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _allTeams.length,
                            itemBuilder: (c, i) {
                              final t = _allTeams[i];
                              final isSel = selectedTeamIds.contains(t.id);
                              return CheckboxListTile(
                                value: isSel,
                                activeColor: const Color(0xFF10B981),
                                title: Row(
                                  children: [
                                    Icon(Icons.circle, color: Color(t.colorValue), size: 14),
                                    const SizedBox(width: 8),
                                    Text(t.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                                subtitle: Text('${t.roster.length} giocatori in rosa', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                                onChanged: (val) {
                                  setMState(() {
                                    if (val == true) {
                                      selectedTeamIds.add(t.id);
                                    } else {
                                      selectedTeamIds.remove(t.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (existing != null) ...[
                        IconButton(
                          icon: const Icon(Icons.delete, color: Color(0xFFEF4444)),
                          tooltip: 'Elimina Torneo',
                          onPressed: () async {
                            final confirmed = await _confirmDeleteTournamentDialog(existing);
                            if (!confirmed) return;

                            await StorageService.deleteTournament(existing.id);
                            if (ctx.mounted) Navigator.pop(ctx);
                            setState(() {
                              _selectedViewId = 'ALL';
                              _activeSubTab = 0;
                            });
                            reload();
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
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

                            final saved = TournamentModel(
                              id: existing?.id ?? 'tour_${DateTime.now().millisecondsSinceEpoch}',
                              name: name,
                              teamIds: selectedTeamIds.toList(),
                              createdAt: existing?.createdAt ?? DateTime.now(),
                            );

                            await StorageService.saveSingleTournament(saved);
                            if (ctx.mounted) Navigator.pop(ctx);
                            setState(() {
                              _selectedViewId = saved.id;
                              _activeSubTab = 0;
                            });
                            reload();
                          },
                          child: const Text('Salva Torneo', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // --- CONVERSIONE SQUADRA PER LANCIO MATCH UFFICIALE TORNEO ---
  int _getRolePriority(PlayerRole role) {
    switch (role) {
      case PlayerRole.POR: return 0;
      case PlayerRole.DIF: return 1;
      case PlayerRole.CEN: return 2;
      case PlayerRole.ATT: return 3;
    }
  }

  List<MatchRosterPlayer> _convertTeamToRoster(TeamModel team) {
    final List<MatchRosterPlayer> roster = [];
    final sortedEntries = List<TeamPlayerEntry>.from(team.roster);

    sortedEntries.sort((a, b) {
      if (a.isStarter != b.isStarter) return a.isStarter ? -1 : 1;
      final pA = _dbPlayers.firstWhere((p) => p.id == a.playerId, orElse: () => PlayerModel(id: '', name: '', role: PlayerRole.CEN, stats: {}));
      final pB = _dbPlayers.firstWhere((p) => p.id == b.playerId, orElse: () => PlayerModel(id: '', name: '', role: PlayerRole.CEN, stats: {}));
      final roleCmp = _getRolePriority(pA.role).compareTo(_getRolePriority(pB.role));
      if (roleCmp != 0) return roleCmp;
      return pB.ovrData.numeric.compareTo(pA.ovrData.numeric);
    });

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

  void _launchOfficialTournamentMatch() {
    if (_selectedHomeTeam == null || _selectedAwayTeam == null || _currentTournament == null) return;

    final homeRoster = _convertTeamToRoster(_selectedHomeTeam!);
    final awayRoster = _convertTeamToRoster(_selectedAwayTeam!);

    widget.onLoadTournamentMatch?.call(
      homeRoster,
      awayRoster,
      _selectedHomeTeam!.name,
      _selectedAwayTeam!.name,
      Color(_selectedHomeTeam!.colorValue),
      Color(_selectedAwayTeam!.colorValue),
      _currentTournament!.id,
    );
  }

  // --- CALCOLO VOTI E MVP PARTITA ---
  Map<String, dynamic> _calculateMatchRatings(MatchHistoryModel m) {
    final Map<String, List<Map<String, dynamic>>> res = {'home': [], 'away': []};
    final int homeTotal = m.homeScore + m.homePenalties;
    final int awayTotal = m.awayScore + m.awayPenalties;
    final hWon = homeTotal > awayTotal;
    final aWon = awayTotal > homeTotal;

    double maxScore = 0.0;
    Map<String, dynamic>? currentMvp;
    bool isDrawMvp = false;

    for (final team in ['home', 'away']) {
      final teamWon = team == 'home' ? hWon : aWon;
      final teamLost = team == 'home' ? aWon : hWon;
      final list = team == 'home' ? m.homeRoster : m.awayRoster;

      for (final p in list) {
        int goals = 0, assists = 0, fouls = 0, yellows = 0, reds = 0, penSaved = 0, penMissed = 0, ownGoals = 0, goalsConceded = 0, errors = 0, bigMisses = 0, bigCreated = 0, goodPlays = 0;

        for (final e in m.events) {
          if (e.isPenalty) continue;
          if (e.playerId == p.dbId) {
            if (e.type == 'GOL' || e.type == 'RIGORE_SEGNATO') goals++;
            if (e.type == 'AUTOGOL') ownGoals++;
            if (e.type == 'FALLO') fouls++;
            if (e.type == 'GIALLO') yellows++;
            if (e.type == 'ROSSO') reds++;
            if (e.type == 'RIGORE_PARATO') penSaved++;
            if (e.type == 'RIGORE_SBAGLIATO') penMissed++;
            if (e.type == 'ERRORE') errors++;
            if (e.type == 'BIG_CHANCE_MISSED') bigMisses++;
            if (e.type == 'BIG_CHANCE_CREATED') bigCreated++;
            if (e.type == 'BUONA_GIOCATA') goodPlays++;
          }
          if (e.type == 'GOL' && e.sub.contains('Assist: #${p.num} ${p.name}')) assists++;
          if ((e.type == 'GOL' || e.type == 'RIGORE_SEGNATO' || e.type == 'AUTOGOL') && e.gkConcededId == p.dbId) goalsConceded++;
        }

        final hasAction = (goals > 0 || assists > 0 || yellows > 0 || reds > 0 || penSaved > 0 || penMissed > 0 || ownGoals > 0 || goalsConceded > 0);
        final playedEnough = p.playedSeconds >= 300;

        if (!hasAction && !playedEnough) {
          res[team]!.add({'id': p.dbId, 'num': p.num, 'name': p.name, 'score': 'SV', 'details': 'Meno di 5m', 'numScore': 0.0, 'isWinner': teamWon, 'bonusCount': 0});
          continue;
        }

        double score = 6.0;
        if (teamWon) {
          score += 0.2;
        } else if (teamLost) {score -= 0.1;}

        if (goals > 0) score += (goals * 1.0);
        if (assists > 0) score += (assists * 0.5);
        if (penSaved > 0) score += (penSaved * 1.2);
        if (penMissed > 0) score -= (penMissed * 0.8);
        if (ownGoals > 0) score -= (ownGoals * 1.0);
        if (yellows > 0) score -= (yellows * 0.5);
        if (reds > 0) score -= (reds * 1.0);
        if (bigCreated > 0) score += (bigCreated * 0.4);
        if (goodPlays > 0) score += (goodPlays * 0.1);
        if (fouls > 0) score -= (fouls * 0.2);
        if (goalsConceded > 0) score -= (goalsConceded * 0.1);
        if (p.gkPlayedSeconds >= 900 && goalsConceded == 0) score += 1.0;
        if (errors > 0) score -= (errors * 0.1);
        if (bigMisses > 0) score -= (bigMisses * 0.4);

        score = score.clamp(1.0, 9.9);

        final pData = {
          'id': p.dbId,
          'num': p.num,
          'name': p.name,
          'score': score.toStringAsFixed(1),
          'numScore': score,
          'isWinner': teamWon,
          'goals': goals,
          'assists': assists,
          'bigCreated': bigCreated,
          'malusCount': fouls + errors + (yellows * 2) + (reds * 4),
          'playedSeconds': p.playedSeconds,
        };

        res[team]!.add(pData);

        if (score > maxScore) {
          maxScore = score;
          currentMvp = pData;
          isDrawMvp = false;
        } else if (score == maxScore && currentMvp != null) {
          final bool pWinner = pData['isWinner'] as bool;
          final bool mvpWinner = currentMvp['isWinner'] as bool;
          if (pWinner && !mvpWinner) {
            currentMvp = pData;
            isDrawMvp = false;
          } else if (pWinner == mvpWinner) {
            if ((pData['goals'] as int) > (currentMvp['goals'] as int)) {
              currentMvp = pData;
              isDrawMvp = false;
            } else if ((pData['goals'] as int) == (currentMvp['goals'] as int)) {
              if ((pData['assists'] as int) > (currentMvp['assists'] as int)) {
                currentMvp = pData;
                isDrawMvp = false;
              } else if ((pData['assists'] as int) == (currentMvp['assists'] as int)) {
                if ((pData['bigCreated'] as int) > (currentMvp['bigCreated'] as int)) {
                  currentMvp = pData;
                  isDrawMvp = false;
                } else if ((pData['malusCount'] as int) < (currentMvp['malusCount'] as int)) {
                  currentMvp = pData;
                  isDrawMvp = false;
                } else if ((pData['playedSeconds'] as int) > (currentMvp['playedSeconds'] as int)) {
                  currentMvp = pData;
                  isDrawMvp = false;
                } else {
                  isDrawMvp = true;
                }
              }
            }
          }
        }
      }
    }

    if (currentMvp != null && !isDrawMvp) {
      currentMvp['isMvp'] = true;
    }
    return res;
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Gestione Dati Partite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scarica o carica il file JSON dello storico partite. L\'importazione aggiungerà solo i nuovi match.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final success = await StorageService.exportMatchesToFile(_matches);
                if (mounted && success) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File storico partite esportato!'), backgroundColor: Color(0xFF10B981)),
                  );
                }
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Scarica File Backup', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: const Color(0xFF042F22),
                minimumSize: const Size.fromHeight(40),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final success = await StorageService.pickAndImportMatchesMerge();
                if (success) {
                  reload();
                  if (mounted) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Partite caricate con successo!'), backgroundColor: Color(0xFF10B981)),
                    );
                  }
                }
              },
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Carica File Backup'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF334155)),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calcTeamAverage(List<Map<String, dynamic>> teamRatings) {
    final validScores = teamRatings
        .where((r) => r['score'] != 'SV' && r['numScore'] != null && (r['numScore'] as double) > 0)
        .map((r) => r['numScore'] as double)
        .toList();

    if (validScores.isEmpty) return 'N.D.';
    final avg = validScores.reduce((a, b) => a + b) / validScores.length;
    return avg.toStringAsFixed(1);
  }

  Widget _buildTeamAvgBadge(String avg, Color teamColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: teamColor.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 9, color: Color(0xFFEAB308)),
          const SizedBox(width: 2.5),
          Text(
            avg,
            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _openMatchDetail(MatchHistoryModel m) {
    final ratings = _calculateMatchRatings(m);
    final homeAvg = _calcTeamAverage(ratings['home']!);
    final awayAvg = _calcTeamAverage(ratings['away']!);

    const salienti = ['GOL', 'RIGORE_SEGNATO', 'RIGORE_SBAGLIATO', 'AUTOGOL', 'GIALLO', 'ROSSO', 'SOSTITUZIONE'];
    final filteredEvents = m.events.where((e) => salienti.contains(e.type)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) {
          return DefaultTabController(
            length: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 20),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.88,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.date, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${m.homeName} ${_getTeamEmoji(m.homeColorValue)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                              ),
                              Text('${m.homeScore} - ${m.awayScore}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                              Expanded(
                                child: Text(
                                  '${_getTeamEmoji(m.awayColorValue)} ${m.awayName}',
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                          if (m.homePenalties > 0 || m.awayPenalties > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text('(Rigori: ${m.homePenalties} - ${m.awayPenalties})', style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10)),
                      child: const TabBar(
                        indicatorColor: Color(0xFF10B981),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: Color(0xFF10B981),
                        unselectedLabelColor: Color(0xFF94A3B8),
                        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        tabs: [
                          Tab(text: '👥 Formazioni & Voti'),
                          Tab(text: '📜 Cronaca'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: TabBarView(
                        children: [
                          SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${_getTeamEmoji(m.homeColorValue)} ${m.homeName.toUpperCase()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                    _buildTeamAvgBadge(homeAvg, Color(m.homeColorValue)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ...ratings['home']!.map((r) => _buildPagellaRow(r)),
                                const Divider(color: Color(0xFF334155), height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${_getTeamEmoji(m.awayColorValue)} ${m.awayName.toUpperCase()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                                    _buildTeamAvgBadge(awayAvg, Color(m.awayColorValue)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ...ratings['away']!.map((r) => _buildPagellaRow(r)),
                              ],
                            ),
                          ),
                          filteredEvents.isEmpty
                              ? const Center(child: Text('Nessuna azione saliente registrata.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)))
                              : Builder(
                                  builder: (context) {
                                    final chronologicalEvents = filteredEvents.reversed.toList();
                                    return ListView.builder(
                                      itemCount: chronologicalEvents.length,
                                      itemBuilder: (c, idx) {
                                        final e = chronologicalEvents[idx];
                                        final String badgeText = e.isPenalty
                                            ? '${chronologicalEvents.sublist(0, idx + 1).where((x) => x.isPenalty && x.team == e.team).length}'
                                            : e.minute.replaceAll(RegExp(r'^(1°TS|2°TS|1°\s*T(empo)?|2°\s*T(empo)?)\s*', caseSensitive: false), '');

                                        final currentPeriod = _getPeriodHeader(e.minute);
                                        final prevPeriod = idx > 0 ? _getPeriodHeader(chronologicalEvents[idx - 1].minute) : '';
                                        final bool showDivider = currentPeriod.isNotEmpty && currentPeriod != prevPeriod;

                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            if (showDivider)
                                              Padding(
                                                padding: EdgeInsets.only(top: idx == 0 ? 4 : 14, bottom: 8),
                                                child: Row(
                                                  children: [
                                                    const Expanded(child: Divider(color: Color(0xFF334155), thickness: 1)),
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                                      child: Text(currentPeriod, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.1)),
                                                    ),
                                                    const Expanded(child: Divider(color: Color(0xFF334155), thickness: 1)),
                                                  ],
                                                ),
                                              ),
                                            Container(
                                              margin: const EdgeInsets.only(bottom: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                textDirection: e.team == 'away' ? TextDirection.rtl : TextDirection.ltr,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                                    child: Text(badgeText, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Courier')),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      textDirection: e.team == 'away' ? TextDirection.rtl : TextDirection.ltr,
                                                      children: [
                                                        Text(e.title, textAlign: e.team == 'away' ? TextAlign.right : TextAlign.left, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                                        if (e.sub.isNotEmpty)
                                                          Text(
                                                            e.sub.replaceAll(RegExp(r'Squadra:\s*[^•\n]+(•\s*)?', caseSensitive: false), '').trim(),
                                                            textAlign: e.team == 'away' ? TextAlign.right : TextAlign.left,
                                                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF334155))),
                            child: const Text('Chiudi', style: TextStyle(color: Color(0xFF94A3B8))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                            icon: const Icon(Icons.delete, size: 16),
                            label: const Text('Elimina', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final confirmed = await _confirmDeleteMatchDialog(m);
                              if (!confirmed) return;

                              await StorageService.deleteMatch(m.id);
                              reload();
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPagellaRow(Map<String, dynamic> r) {
    final isMvp = r['isMvp'] == true;
    final isSV = r['score'] == 'SV';
    final double scoreVal = double.tryParse(r['score']?.toString() ?? '') ?? 0.0;

    Color badgeColor;
    if (isMvp) {
      badgeColor = const Color(0xFF0044FF);
    } else if (isSV) { badgeColor = const Color(0xFF334155); }
    else if (scoreVal >= 6.8) { badgeColor = const Color(0xFF0A7227); }
    else if (scoreVal >= 5.8) { badgeColor = const Color(0xFFD97706); }
    else { badgeColor = const Color(0xFFD50000); }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Text('#${r['num']} ${r['name']}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                if (isMvp)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFF0044FF), borderRadius: BorderRadius.circular(4)),
                    child: const Text('MVP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
            child: Text(r['score'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTournament = _currentTournament != null;

    return Column(
      children: [
        // BARRA SUPERIORE: SELETTORE MODALITÀ / TORNEO + TASTO NUOVO TORNEO + BACKUP
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          color: const Color(0xFF111827),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedViewId,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('🌐 Tutte le Partite')),
                        const DropdownMenuItem(value: 'FRIENDLY', child: Text('⚽ Solo Amichevoli')),
                        ..._tournaments.map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text('🏆 ${t.name.toUpperCase()}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900)),
                            )),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedViewId = val;
                            _activeSubTab = 0;
                            _selectedHomeTeam = null;
                            _selectedAwayTeam = null;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              if (isTournament) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit_note, color: Color(0xFF10B981), size: 22),
                  tooltip: 'Modifica Squadre Torneo',
                  onPressed: () => _openTournamentModal(_currentTournament),
                ),
              ],
              const SizedBox(width: 4),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: const Color(0xFF042F22),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openTournamentModal(),
                icon: const Icon(Icons.emoji_events, size: 16),
                label: const Text('+ Torneo', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              ),
              IconButton(
                icon: const Icon(Icons.cloud_sync, color: Color(0xFF94A3B8), size: 20),
                onPressed: _showBackupDialog,
                tooltip: 'Backup Storico Partite',
              ),
            ],
          ),
        ),

        // INTESTAZIONE STILE STEPH LEAGUE E SOTTO-SCHEDE
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF090D16),
            border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
          ),
          child: Column(
            children: [
              if (isTournament) ...[
                Text(
                  _currentTournament!.name.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
              ],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: isTournament
                      ? [
                          _subTabPill(0, 'CLASSIFICA'),
                          _subTabPill(1, 'PARTITE'),
                          _subTabPill(2, 'MARCATORI'),
                          _subTabPill(3, 'SQUADRE'),
                        ]
                      : [
                          _subTabPill(0, 'PARTITE'),
                          _subTabPill(1, 'MARCATORI'),
                        ],
                ),
              ),
            ],
          ),
        ),

        // CONTENUTO DELLA SOTTO-SCHEDA ATTIVA
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
              : _buildCurrentSubTabContent(isTournament),
        ),
      ],
    );
  }

  Widget _subTabPill(int index, String label) {
    final active = _activeSubTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _activeSubTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1E293B) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? const Color(0xFF10B981).withValues(alpha: 0.5) : Colors.transparent),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentSubTabContent(bool isTournament) {
    if (!isTournament) {
      return _activeSubTab == 0 ? _buildMatchesTab() : _buildScorersTab();
    } else {
      switch (_activeSubTab) {
        case 0:
          return _buildLeagueTableTab(_currentTournament!);
        case 1:
          return _buildMatchesTab();
        case 2:
          return _buildScorersTab();
        case 3:
          return _buildTournamentTeamsTab(_currentTournament!);
        default:
          return _buildLeagueTableTab(_currentTournament!);
      }
    }
  }

  // --- SCHEDA 1 TORNEO: CLASSIFICA + LEGENDA RIFORMATTATA (PUNTO 7) ---
  Widget _buildLeagueTableTab(TournamentModel tournament) {
    final rows = _calculateLeagueTable(tournament);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CLASSIFICA', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              children: [
                // Header Tabella
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 26, child: Text('POS', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w900))),
                      Expanded(child: Text('SQUADRA', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w900))),
                      SizedBox(width: 28, child: Text('PT', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w900))),
                      SizedBox(width: 24, child: Text('G', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold))),
                      SizedBox(width: 24, child: Text('V', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold))),
                      SizedBox(width: 24, child: Text('N', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold))),
                      SizedBox(width: 24, child: Text('S', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold))),
                      SizedBox(width: 26, child: Text('GF', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold))),
                      SizedBox(width: 26, child: Text('GS', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold))),
                      SizedBox(width: 28, child: Text('DR', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Nessuna squadra iscritta.\nVai nella scheda "SQUADRE" o clicca l\'icona modifica in alto per aggiungere partecipanti!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ),
                  )
                else
                  ...rows.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final r = entry.value;
                    final drStr = r.goalDifference > 0 ? '+${r.goalDifference}' : '${r.goalDifference}';
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                color: idx == 0 ? const Color(0xFFEAB308) : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 16,
                                  decoration: BoxDecoration(color: Color(r.teamColorValue), borderRadius: BorderRadius.circular(2)),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    r.teamName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 28, child: Text('${r.points}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 14))),
                          SizedBox(width: 24, child: Text('${r.played}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12))),
                          SizedBox(width: 24, child: Text('${r.won}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
                          SizedBox(width: 24, child: Text('${r.drawn}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
                          SizedBox(width: 24, child: Text('${r.lost}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
                          SizedBox(width: 26, child: Text('${r.goalsFor}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
                          SizedBox(width: 26, child: Text('${r.goalsAgainst}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
                          SizedBox(
                            width: 28,
                            child: Text(
                              drStr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: r.goalDifference > 0 ? const Color(0xFF10B981) : (r.goalDifference < 0 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8)),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // BOX LEGENDA PULITO (SOLO PUNTI ED EX-AEQUO)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Legenda:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                ),
                SizedBox(height: 8),

                Text(
                  'Assegnazione Punti (PT):',
                  style: TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.bold, fontSize: 11),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 12, top: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• V (Vittoria): +3 pt', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      Text('• N (Pareggio): +1 pt', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      Text('• S (Sconfitta): 0 pt', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ),
                SizedBox(height: 10),

                Text(
                  'Criteri in caso di parità di PT (Ex-Aequo):',
                  style: TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.bold, fontSize: 11),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 12, top: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('1. Miglior DR (Differenza Reti: GF - GS)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      Text('2. Maggior numero di GF (Gol Fatti)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      Text('3. Esito dello Scontro Diretto', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SCHEDA 4 TORNEO: SQUADRE ISCRITTE E LANCIO PARTITA UFFICIALE ---
  Widget _buildTournamentTeamsTab(TournamentModel tournament) {
    final enrolledTeams = _allTeams.where((t) => tournament.teamIds.contains(t.id)).toList();
    final canLaunch = _selectedHomeTeam != null && _selectedAwayTeam != null;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (_selectedHomeTeam != null || _selectedAwayTeam != null)
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
                          _selectedHomeTeam != null ? '🏠 CASA: ${_selectedHomeTeam!.name}' : 'Seleziona CASA',
                          style: TextStyle(
                            color: _selectedHomeTeam != null ? Color(_selectedHomeTeam!.colorValue) : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('VS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                      ),
                      Expanded(
                        child: Text(
                          _selectedAwayTeam != null ? '🚗 OSPITI: ${_selectedAwayTeam!.name}' : 'Seleziona OSPITI',
                          style: TextStyle(
                            color: _selectedAwayTeam != null ? Color(_selectedAwayTeam!.colorValue) : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => setState(() {
                          _selectedHomeTeam = null;
                          _selectedAwayTeam = null;
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
                  if (canLaunch) ...[
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
                        onPressed: _launchOfficialTournamentMatch,
                        icon: const Icon(Icons.sports_soccer, size: 18),
                        label: Text('GIOCA MATCH (${tournament.name.toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: enrolledTeams.isEmpty
                ? const Center(
                    child: Text(
                      'Nessuna squadra iscritta a questo torneo.\nUsa il pulsante qui sotto per aggiungerle!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  )
                : ListView.builder(
                    itemCount: enrolledTeams.length,
                    itemBuilder: (ctx, i) {
                      final team = enrolledTeams[i];
                      final isHome = _selectedHomeTeam?.id == team.id;
                      final isAway = _selectedAwayTeam?.id == team.id;
                      final isSelected = isHome || isAway;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (_selectedHomeTeam?.id == team.id) {
                              _selectedHomeTeam = null;
                            } else if (_selectedAwayTeam?.id == team.id) {
                              _selectedAwayTeam = null;
                            } else if (_selectedHomeTeam == null) {
                              _selectedHomeTeam = team;
                            } else {
                              _selectedAwayTeam = team;
                            }
                          });
                        },
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
                              Container(width: 10, height: 34, decoration: BoxDecoration(color: Color(team.colorValue), borderRadius: BorderRadius.circular(4))),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  team.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              if (isHome) const Text('[CASA]', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 11)),
                              if (isAway) const Text('[OSPITI]', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w900, fontSize: 11)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF334155)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _openTournamentModal(tournament),
              icon: const Icon(Icons.group_add, color: Colors.white, size: 18),
              label: const Text('Gestisci Squadre Iscritte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // --- SCHEDA PARTITE ---
  Widget _buildMatchesTab() {
    final list = _filteredMatches;
    if (list.isEmpty) {
      return const Center(child: Text('Nessuna partita registrata in questa sezione.', style: TextStyle(color: Color(0xFF94A3B8))));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final m = list[i];
        return InkWell(
          onTap: () => _openMatchDetail(m),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(m.date, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                    Text('${m.events.length} Eventi', style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('${m.homeName} ${_getTeamEmoji(m.homeColorValue)}', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: [
                          Text('${m.homeScore} - ${m.awayScore}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                          if (m.homePenalties > 0 || m.awayPenalties > 0)
                            Text('(${m.homePenalties}-${m.awayPenalties})', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(child: Text('${_getTeamEmoji(m.awayColorValue)} ${m.awayName}', textAlign: TextAlign.left, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- SCHEDA MARCATORI ---
  Widget _buildScorersTab() {
    final scorers = _getScorersRanking();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: const Color(0xFF111827),
          child: const Row(
            children: [
              SizedBox(width: 30, child: Text('POS', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(child: Text('GIOCATORE', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold))),
              SizedBox(width: 40, child: Text('GOL', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold))),
              SizedBox(width: 40, child: Text('ASS', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        Expanded(
          child: scorers.isEmpty
              ? const Center(child: Text('Nessun giocatore presente.', style: TextStyle(color: Color(0xFF94A3B8))))
              : ListView.builder(
                  itemCount: scorers.length,
                  itemBuilder: (ctx, i) {
                    final s = scorers[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E293B)))),
                      child: Row(
                        children: [
                          SizedBox(width: 30, child: Text('${i + 1}', style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold))),
                          Expanded(child: Text(s['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                          SizedBox(width: 40, child: Text('${s['goals']}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 16))),
                          SizedBox(width: 40, child: Text('${s['assists']}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w900, fontSize: 16))),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}