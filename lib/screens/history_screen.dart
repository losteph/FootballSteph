import 'package:flutter/material.dart';
import '../models/match_history_model.dart';
import '../models/player_model.dart';
import '../services/storage_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MatchHistoryModel> _matches = [];
  List<PlayerModel> _dbPlayers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    reload();
  }

  Future<void> reload() async {
    if (mounted) setState(() => _isLoading = true);
    final matches = await StorageService.loadMatches();
    final players = await StorageService.loadPlayers();
    if (mounted) {
      setState(() {
        _matches = matches;
        _dbPlayers = players;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  List<Map<String, dynamic>> _getScorersRanking() {
    final Map<String, Map<String, dynamic>> stats = {};

    for (var p in _dbPlayers) {
      stats[p.name] = {'name': p.name, 'goals': 0, 'assists': 0};
    }

    for (var m in _matches) {
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
      return (b['assists'] as int).compareTo(a['assists'] as int);
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

  Map<String, dynamic> _calculateMatchRatings(MatchHistoryModel m) {
    final Map<String, List<Map<String, dynamic>>> res = {'home': [], 'away': []};
    
    final int homeTotal = m.homeScore + m.homePenalties;
    final int awayTotal = m.awayScore + m.awayPenalties;
    final hWon = homeTotal > awayTotal;
    final aWon = awayTotal > homeTotal;

    double maxScore = 0.0;
    Map<String, dynamic>? currentMvp;

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

        final hasAction = (goals > 0 || assists > 0 || fouls > 0 || yellows > 0 || reds > 0 || penSaved > 0 || penMissed > 0 || ownGoals > 0 || goalsConceded > 0 || errors > 0 || bigMisses > 0 || bigCreated > 0 || goodPlays > 0);
        final playedEnough = p.playedSeconds >= 300;

        if (!hasAction && !playedEnough) {
          res[team]!.add({'id': p.dbId, 'num': p.num, 'name': p.name, 'score': 'S.V.', 'details': 'Meno di 5m', 'numScore': 0.0, 'isWinner': teamWon, 'bonusCount': 0});
          continue;
        }

        double score = 6.0;
        final details = <String>[];

        if (teamWon) { score += 0.5; details.add('+0.5 vit'); }
        else if (teamLost) { score -= 0.5; details.add('-0.5 sco'); }

        if (goals > 0) { score += (goals * 1.0); details.add('+$goals gol'); }
        if (assists > 0) { score += (assists * 0.5); details.add('+${assists * 0.5} ass'); }
        if (penSaved > 0) { score += (penSaved * 1.5); details.add('+${penSaved * 1.5} rig.par'); }
        if (penMissed > 0) { score -= (penMissed * 1.5); details.add('-${penMissed * 1.5} rig.sbagl'); }
        if (ownGoals > 0) { score -= (ownGoals * 1.0); details.add('-$ownGoals aut'); }
        if (yellows > 0) { score -= (yellows * 1.0); details.add('-$yellows gia'); }
        if (reds > 0) { score -= (reds * 2.0); details.add('-${reds * 2} ros'); }
        if (bigCreated > 0) { score += (bigCreated * 0.5); details.add('+${bigCreated * 0.5} ch.cre'); }
        if (goodPlays > 0) { score += (goodPlays * 0.1); details.add('+${(goodPlays * 0.1).toStringAsFixed(1)} gioc'); }

        final foulMalus = fouls * 0.2;
        if (foulMalus > 0) { score -= foulMalus; details.add('-$foulMalus falli'); }

        final gkMalus = goalsConceded * 0.2;
        if (gkMalus > 0) { score -= gkMalus; details.add('-$gkMalus gol sub'); }

        if (p.gkPlayedSeconds >= 900 && goalsConceded == 0) { score += 1.0; details.add('+1.0 clean sheet'); }

        final errMalus = errors * 0.1;
        if (errMalus > 0) { score -= errMalus; details.add('-$errMalus err'); }

        if (bigMisses > 0) { score -= (bigMisses * 0.5); details.add('-${bigMisses * 0.5} gol div'); }

        score = score.clamp(1.0, 10.0);

        final pData = {
          'id': p.dbId, 'num': p.num, 'name': p.name,
          'score': score.toStringAsFixed(1), 'numScore': score,
          'details': details.isNotEmpty ? details.join(', ') : 'Base 6.0',
          'isWinner': teamWon, 'goals': goals,
          'assists': assists,
          'bigCreated': bigCreated,
          'malusCount': fouls + errors + (yellows * 2) + (reds * 4),
          'playedSeconds': p.playedSeconds,
        };

        res[team]!.add(pData);

        if (score > maxScore) {
          maxScore = score;
          currentMvp = pData;
        } else if (score == maxScore && currentMvp != null) {
          final bool pWinner = pData['isWinner'] as bool;
          final bool mvpWinner = currentMvp['isWinner'] as bool;

          if (pWinner && !mvpWinner) {
            currentMvp = pData; // 1. Ha vinto la partita (anche ai rigori)
          } else if (pWinner == mvpWinner) {
            if ((pData['goals'] as int) > (currentMvp['goals'] as int)) {
              currentMvp = pData; // 2. Più gol segnati
            } else if ((pData['goals'] as int) == (currentMvp['goals'] as int)) {
              if ((pData['assists'] as int) > (currentMvp['assists'] as int)) {
                currentMvp = pData; // 3. Più assist
              } else if ((pData['assists'] as int) == (currentMvp['assists'] as int)) {
                if ((pData['bigCreated'] as int) > (currentMvp['bigCreated'] as int)) {
                  currentMvp = pData; // 4. Più occasioni create
                } else if ((pData['malusCount'] as int) < (currentMvp['malusCount'] as int)) {
                  currentMvp = pData; // 5. Meno malus disciplinari/errori
                } else if ((pData['playedSeconds'] as int) > (currentMvp['playedSeconds'] as int)) {
                  currentMvp = pData; // 6. Più minutaggio in campo
                }
              }
            }
          }
        }
      }
    }

    if (currentMvp != null && maxScore > 6.0) {
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
                  Navigator.pop(ctx);
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
                    Navigator.pop(ctx);
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

  void _openMatchDetail(MatchHistoryModel m) {
    final ratings = _calculateMatchRatings(m);

    // Filtro rigoroso: solo azioni salienti reali
    const salienti = ['GOL', 'RIGORE_SEGNATO', 'RIGORE_SBAGLIATO', 'RIGORE_PARATO', 'AUTOGOL', 'GIALLO', 'ROSSO', 'FALLO', 'SOSTITUZIONE'];
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

                    // Testata Risultato
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
                                  '${_getTeamEmoji(m.homeColorValue)} ${m.homeName}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(m.homeColorValue), fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                              ),
                              Text('${m.homeScore} - ${m.awayScore}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                              Expanded(
                                child: Text(
                                  '${m.awayName} ${_getTeamEmoji(m.awayColorValue)}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(m.awayColorValue), fontWeight: FontWeight.w900, fontSize: 15),
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

                    // Barra Schede nel Modal (Lineup vs Cronaca Saliente)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
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

                    // Contenuto Schede
                    Expanded(
                      child: TabBarView(
                        children: [
                          // SCHEDA 1: FORMAZIONI E PAGELLE
                          SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${_getTeamEmoji(m.homeColorValue)} ${m.homeName.toUpperCase()}', style: TextStyle(color: Color(m.homeColorValue), fontWeight: FontWeight.w900, fontSize: 13)),
                                const SizedBox(height: 4),
                                ...ratings['home']!.map((r) => _buildPagellaRow(r)),
                                const Divider(color: Color(0xFF334155), height: 24),
                                Text('${_getTeamEmoji(m.awayColorValue)} ${m.awayName.toUpperCase()}', style: TextStyle(color: Color(m.awayColorValue), fontWeight: FontWeight.w900, fontSize: 13)),
                                const SizedBox(height: 4),
                                ...ratings['away']!.map((r) => _buildPagellaRow(r)),
                              ],
                            ),
                          ),

                          // SCHEDA 2: CRONACA SALIENTE
                          filteredEvents.isEmpty
                              ? const Center(child: Text('Nessuna azione saliente registrata.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)))
                              : ListView.builder(
                                  itemCount: filteredEvents.length,
                                  itemBuilder: (c, idx) {
                                    final e = filteredEvents.reversed.toList()[idx];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              e.minute,
                                              style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Courier'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(e.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                                if (e.sub.isNotEmpty)
                                                  Text(e.sub, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
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
                              await StorageService.deleteMatch(m.id);
                              reload();
                              if (mounted) Navigator.pop(ctx);
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
    final isSV = r['score'] == 'S.V.';

    Color badgeColor;
    if (isMvp) {
      badgeColor = const Color(0xFF0044FF); // Blu MVP
    } else if (isSV) badgeColor = const Color(0xFF334155); // Grigio S.V.
    else if (r['numScore'] >= 6.0) badgeColor = const Color(0xFF0A7227); // Verde
    else badgeColor = const Color(0xFFD50000); // Rosso

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('#${r['num']} ${r['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    if (isMvp)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFF0044FF), borderRadius: BorderRadius.circular(4)),
                        child: const Text('MVP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                  ],
                ),
                Text(r['details'], style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
            child: Text(
              r['score'],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF111827),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF10B981),
                  labelColor: const Color(0xFF10B981),
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  tabs: const [
                    Tab(text: 'PARTITE'),
                    Tab(text: 'MARCATORI'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.cloud_sync, color: Color(0xFF94A3B8)),
                onPressed: _showBackupDialog,
                tooltip: 'Backup e Ripristino File Partite',
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMatchesTab(),
                    _buildScorersTab(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildMatchesTab() {
    if (_matches.isEmpty) {
      return const Center(child: Text('Nessuna partita archiviata.', style: TextStyle(color: Color(0xFF94A3B8))));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _matches.length,
      itemBuilder: (ctx, i) {
        final m = _matches[i];
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
                    Expanded(child: Text('${_getTeamEmoji(m.homeColorValue)} ${m.homeName}', textAlign: TextAlign.right, style: TextStyle(color: Color(m.homeColorValue), fontWeight: FontWeight.w900, fontSize: 15))),
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
                    Expanded(child: Text('${m.awayName} ${_getTeamEmoji(m.awayColorValue)}', textAlign: TextAlign.left, style: TextStyle(color: Color(m.awayColorValue), fontWeight: FontWeight.w900, fontSize: 15))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
          child: ListView.builder(
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