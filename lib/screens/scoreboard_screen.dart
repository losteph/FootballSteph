import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/match_roster_player.dart';
import '../models/match_event_model.dart';
import '../models/match_history_model.dart';
import '../services/storage_service.dart';

class ScoreboardScreen extends StatefulWidget {
  final List<MatchRosterPlayer> initialHomePlayers;
  final List<MatchRosterPlayer> initialAwayPlayers;
  final VoidCallback? onMatchFinished;

  const ScoreboardScreen({
    super.key,
    required this.initialHomePlayers,
    required this.initialAwayPlayers,
    this.onMatchFinished,
  });

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  Timer? _matchTimer;
  int _durationSeconds = 15 * 60;
  int _currentSeconds = 15 * 60;
  String _timerMode = 'countdown';
  bool _isMatchRunning = false;
  int _currentPeriod = 1;
  String _periodLabel = '1° Tempo';

  Timer? _gkTimer;
  int _gkDurationSeconds = 5 * 60;
  int _gkCurrentSeconds = 5 * 60;
  bool _isGkRunning = false;

  final TextEditingController _homeNameCtrl = TextEditingController(text: 'CASA');
  final TextEditingController _awayNameCtrl = TextEditingController(text: 'OSPITI');
  
  final TextEditingController _matchMinCtrl = TextEditingController(text: '15');
  final TextEditingController _matchSecCtrl = TextEditingController(text: '00');
  final TextEditingController _gkMinCtrl = TextEditingController(text: '5');

  // Controllers per l'aggiunta di giocatori on the go
  final TextEditingController _addNumHomeCtrl = TextEditingController();
  final TextEditingController _addNameHomeCtrl = TextEditingController();
  final TextEditingController _addNumAwayCtrl = TextEditingController();
  final TextEditingController _addNameAwayCtrl = TextEditingController();

  int _homeScore = 0;
  int _awayScore = 0;
  int _homePenalties = 0;
  int _awayPenalties = 0;

  Color _homeColor = const Color(0xFF3B82F6);
  Color _awayColor = const Color(0xFFEF4444);

  late List<MatchRosterPlayer> _homePlayers;
  late List<MatchRosterPlayer> _awayPlayers;
  List<MatchRosterPlayer>? _initialLineupHome;
  List<MatchRosterPlayer>? _initialLineupAway;

  final List<MatchEventModel> _events = [];

  final Map<String, Color> _colorOptions = const {
    '🔵 Blu': Color(0xFF3B82F6),
    '🔴 Rosso': Color(0xFFEF4444),
    '🟢 Verde': Color(0xFF10B981),
    '🟡 Giallo': Color(0xFFEAB308),
    '🟠 Arancio': Color(0xFFF97316),
    '🟣 Viola': Color(0xFF8B5CF6),
    '⚫ Nero': Color(0xFF1E293B),
    '⚪ Bianco': Color(0xFFF8FAFC),
  };

  String _getTeamEmoji(Color color) {
    if (color == const Color(0xFF3B82F6)) return '🔵';
    if (color == const Color(0xFFEF4444)) return '🔴';
    if (color == const Color(0xFF10B981)) return '🟢';
    if (color == const Color(0xFFEAB308)) return '🟡';
    if (color == const Color(0xFFF97316)) return '🟠';
    if (color == const Color(0xFF8B5CF6)) return '🟣';
    if (color == const Color(0xFF1E293B)) return '⚫';
    if (color == const Color(0xFFF8FAFC)) return '⚪';
    return '⚽';
  }

  @override
  void initState() {
    super.initState();
    _setupInitialRosters();
  }

  @override
  void didUpdateWidget(covariant ScoreboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialHomePlayers.isNotEmpty &&
        widget.initialHomePlayers != oldWidget.initialHomePlayers) {
      _setupInitialRosters();
    }
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    _gkTimer?.cancel();
    _homeNameCtrl.dispose();
    _awayNameCtrl.dispose();
    _matchMinCtrl.dispose();
    _matchSecCtrl.dispose();
    _gkMinCtrl.dispose();
    _addNumHomeCtrl.dispose();
    _addNameHomeCtrl.dispose();
    _addNumAwayCtrl.dispose();
    _addNameAwayCtrl.dispose();
    super.dispose();
  }

  void _setupInitialRosters() {
    if (widget.initialHomePlayers.isNotEmpty) {
      _homePlayers = List.from(widget.initialHomePlayers.map((e) => MatchRosterPlayer.fromJson(e.toJson())));
    } else {
      final defaultHomeNames = ['POR 1', 'TS 1', 'DC 1', 'DC 2', 'TD 1', 'CC 1', 'COC 1', 'CDC 1', 'ED 1', 'ES 1', 'ATT 1', 'Riserva 1'];
      _homePlayers = List.generate(
        12,
        (i) => MatchRosterPlayer(
          dbId: 'h_$i',
          num: '${i + 1}',
          name: defaultHomeNames[i],
          inField: i < 11,
          isGK: i == 0,
        ),
      );
    }

    if (widget.initialAwayPlayers.isNotEmpty) {
      _awayPlayers = List.from(widget.initialAwayPlayers.map((e) => MatchRosterPlayer.fromJson(e.toJson())));
    } else {
      final defaultAwayNames = ['POR 2', 'TS 2', 'DC 3', 'DC 4', 'TD 2', 'CC 2', 'COC 2', 'CDC 2', 'ED 2', 'ES 2', 'ATT 2', 'Riserva 2'];
      _awayPlayers = List.generate(
        12,
        (i) => MatchRosterPlayer(
          dbId: 'a_$i',
          num: '${i + 1}',
          name: defaultAwayNames[i],
          inField: i < 11,
          isGK: i == 0,
        ),
      );
    }
  }

  void _removePlayerFromRoster(String team, int idx) {
    setState(() {
      if (team == 'home') {
        _homePlayers.removeAt(idx);
      } else {
        _awayPlayers.removeAt(idx);
      }
    });
  }

  void _addPlayerToRoster(String team) {
    final isHome = team == 'home';
    final numCtrl = isHome ? _addNumHomeCtrl : _addNumAwayCtrl;
    final nameCtrl = isHome ? _addNameHomeCtrl : _addNameAwayCtrl;

    final name = nameCtrl.text.trim();
    final num = numCtrl.text.trim();

    if (name.isEmpty) return;

    setState(() {
      final newPlayer = MatchRosterPlayer(
        dbId: '${team}_new_${DateTime.now().millisecondsSinceEpoch}',
        num: num.isEmpty ? '?' : num,
        name: name,
        inField: true,
        isGK: false,
      );

      if (isHome) {
        _homePlayers.add(newPlayer);
      } else {
        _awayPlayers.add(newPlayer);
      }
      
      numCtrl.clear();
      nameCtrl.clear();
    });
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _getElapsedFormatted() {
    if (_currentPeriod == 5) return 'RIGORI';
    if (_timerMode == 'countdown') {
      final elapsed = _durationSeconds - _currentSeconds;
      return '$_periodLabel ${_formatTime(elapsed < 0 ? 0 : elapsed)}';
    } else {
      return '$_periodLabel ${_formatTime(_currentSeconds)}';
    }
  }

  void _setTimerMode(String mode) {
    if (_timerMode == mode) return;
    setState(() {
      _timerMode = mode;
      _currentSeconds = (_durationSeconds - _currentSeconds).clamp(0, _durationSeconds);
    });
  }

  void _applyDurationSettings() {
    int m = int.tryParse(_matchMinCtrl.text) ?? 15;
    int s = int.tryParse(_matchSecCtrl.text) ?? 0;
    setState(() {
      _durationSeconds = (m * 60) + s;
      _currentSeconds = _timerMode == 'countdown' ? _durationSeconds : 0;
    });
  }

  void _applyGkDurationSettings() {
    int m = int.tryParse(_gkMinCtrl.text) ?? 5;
    setState(() {
      _gkDurationSeconds = m * 60;
      _gkCurrentSeconds = _gkDurationSeconds;
      _isGkRunning = false;
      _gkTimer?.cancel();
    });
  }

  void _toggleMatchTimer() {
    if (_currentPeriod == 5) return;
    if (_isMatchRunning) {
      _matchTimer?.cancel();
      setState(() => _isMatchRunning = false);
    } else {
      if (_currentPeriod == 1 && _initialLineupHome == null) {
        setState(() {
          _initialLineupHome = _homePlayers.map((p) => MatchRosterPlayer.fromJson(p.toJson())).toList();
          _initialLineupAway = _awayPlayers.map((p) => MatchRosterPlayer.fromJson(p.toJson())).toList();
        });
      }
      _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          for (final p in _homePlayers) {
            if (p.inField) {
              p.playedSeconds++;
              if (p.isGK) p.gkPlayedSeconds++;
            }
          }
          for (final p in _awayPlayers) {
            if (p.inField) {
              p.playedSeconds++;
              if (p.isGK) p.gkPlayedSeconds++;
            }
          }

          if (_timerMode == 'countdown') {
            if (_currentSeconds > 0) {
              _currentSeconds--;
            } else {
              _finishTimer();
            }
          } else {
            if (_currentSeconds < _durationSeconds) {
              _currentSeconds++;
            } else {
              _finishTimer();
            }
          }
        });
      });
      setState(() => _isMatchRunning = true);
    }
  }

  void _finishTimer() {
    _matchTimer?.cancel();
    setState(() => _isMatchRunning = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('FINE TEMPO ($_periodLabel)!'), backgroundColor: const Color(0xFFEF4444)),
    );
  }

  void _toggleGkTimer() {
    if (_isGkRunning) {
      _gkTimer?.cancel();
      setState(() => _isGkRunning = false);
    } else {
      _gkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_gkCurrentSeconds > 0) {
            _gkCurrentSeconds--;
          } else {
            _gkTimer?.cancel();
            _isGkRunning = false;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔔 CAMBIO PORTIERE! Turno terminato.'),
                backgroundColor: Color(0xFF06B6D4),
                duration: Duration(seconds: 4),
              ),
            );
          }
        });
      });
      setState(() => _isGkRunning = true);
    }
  }

  void _resetGkTimer() {
    _gkTimer?.cancel();
    setState(() {
      _isGkRunning = false;
      _gkCurrentSeconds = _gkDurationSeconds;
    });
  }

  void _selectPeriod(int num, String label) {
    setState(() {
      _currentPeriod = num;
      _periodLabel = label;
      if (num == 5) {
        _matchTimer?.cancel();
        _isMatchRunning = false;
      } else {
        _currentSeconds = _timerMode == 'countdown' ? _durationSeconds : 0;
      }
    });
    _logEvent('⏱️ Inizio $label', 'Comunicazione ufficiale', _getElapsedFormatted());
  }

  MatchRosterPlayer? _getCurrentGK(String team) {
    final list = team == 'home' ? _homePlayers : _awayPlayers;
    return list.firstWhere((p) => p.isGK && p.inField,
        orElse: () => list.firstWhere((p) => p.isGK, orElse: () => list.first));
  }

  void _quickGoal(String team) {
    final isHome = team == 'home';
    final teamName = isHome ? _homeNameCtrl.text : _awayNameCtrl.text;
    final opposingTeamKey = isHome ? 'away' : 'home';
    final opposingGK = _getCurrentGK(opposingTeamKey);

    setState(() {
      if (_currentPeriod == 5) {
        if (isHome) {
          _homePenalties++;
        } else {
          _awayPenalties++;
        }
        _logEvent('👟 Rigore Segnato ($teamName)', 'Sequenza Rigori', _getElapsedFormatted(), team: team, isPenalty: true, type: 'RIGORE_SEGNATO');
      } else {
        if (isHome) {
          _homeScore++;
        } else {
          _awayScore++;
        }
        var subText = 'Squadra: $teamName';
        if (opposingGK != null) subText += ' • (Gol subito: #${opposingGK.num} ${opposingGK.name})';
        _logEvent('⚽ GOL', subText, _getElapsedFormatted(), team: team, type: 'GOL', gkConcededId: opposingGK?.dbId);
      }
    });
  }

  void _promptMinusGoal(String team) {
    final isPen = _currentPeriod == 5;
    final targetList = _events.where((e) {
      if (e.team != team) return false;
      if (isPen) return e.isPenalty && e.type == 'RIGORE_SEGNATO';
      return !e.isPenalty && (e.type == 'GOL' || e.type == 'RIGORE_SEGNATO');
    }).toList();

    if (targetList.isEmpty) {
      setState(() {
        if (isPen) {
          if (team == 'home') {
            _homePenalties = (_homePenalties - 1).clamp(0, 99);
          } else {
            _awayPenalties = (_awayPenalties - 1).clamp(0, 99);
          }
        } else {
          if (team == 'home') {
            _homeScore = (_homeScore - 1).clamp(0, 99);
          } else {
            _awayScore = (_awayScore - 1).clamp(0, 99);
          }
        }
      });
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Quale gol vuoi annullare?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: targetList.length,
            itemBuilder: (c, i) {
              final ev = targetList[i];
              return ListTile(
                title: Text('${ev.minute} - ${ev.title}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () {
                  _deleteEvent(ev);
                  Navigator.pop(ctx);
                },
              );
            }
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Annulla', style: TextStyle(color: Color(0xFF94A3B8)))
          ),
        ],
      ),
    );
  }

  void _logEvent(String title, String sub, String minute, {String? team, bool isPenalty = false, String type = 'OTHER', String? playerId, String? gkConcededId}) {
    setState(() {
      _events.insert(0, MatchEventModel(
        id: DateTime.now().millisecondsSinceEpoch, title: title, sub: sub, minute: minute,
        team: team, isPenalty: isPenalty, type: type, playerId: playerId, gkConcededId: gkConcededId,
      ));
    });
  }

  void _deleteEvent(MatchEventModel ev) {
    setState(() {
      if (ev.isPenalty && ev.type == 'RIGORE_SEGNATO') {
        if (ev.team == 'home') _homePenalties = (_homePenalties - 1).clamp(0, 99);
        if (ev.team == 'away') _awayPenalties = (_awayPenalties - 1).clamp(0, 99);
      } else if (!ev.isPenalty && (ev.type == 'GOL' || ev.type == 'RIGORE_SEGNATO' || ev.type == 'AUTOGOL')) {
        if (ev.team == 'home') _homeScore = (_homeScore - 1).clamp(0, 99);
        if (ev.team == 'away') _awayScore = (_awayScore - 1).clamp(0, 99);
      }
      _events.removeWhere((e) => e.id == ev.id);
    });
  }

  void _confirmEndMatch() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Conferma Fine Partita', style: TextStyle(color: Colors.white)),
        content: const Text('Terminare la gara e salvare i dati nello storico?', style: TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Annulla', style: TextStyle(color: Color(0xFF94A3B8)))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.pop(ctx);
              
              final finalHomeRoster = _initialLineupHome ?? _homePlayers;
              final finalAwayRoster = _initialLineupAway ?? _awayPlayers;
              
              final now = DateTime.now();
              final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

              // 1. Crea l'oggetto partita
              final newMatch = MatchHistoryModel(
                id: now.millisecondsSinceEpoch.toString(),
                title: '${_homeNameCtrl.text} vs ${_awayNameCtrl.text}',
                date: dateStr,
                homeName: _homeNameCtrl.text,
                awayName: _awayNameCtrl.text,
                homeScore: _homeScore,
                awayScore: _awayScore,
                homePenalties: _homePenalties,
                awayPenalties: _awayPenalties,
                homeColorValue: _homeColor.toARGB32(),
                awayColorValue: _awayColor.toARGB32(),
                homeRoster: finalHomeRoster,
                awayRoster: finalAwayRoster,
                events: _events,
              );

              // 2. Salva nel database locale
              await StorageService.saveMatch(newMatch);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Partita archiviata con successo!'), backgroundColor: Color(0xFF10B981))
                );
                // 3. Avvisa il main.dart di cambiare tab
                widget.onMatchFinished?.call();
              }
            },
            child: const Text('Fine Partita', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _setGoalkeeper(String team, int idx) {
    final list = team == 'home' ? _homePlayers : _awayPlayers;
    setState(() {
      for (var i = 0; i < list.length; i++) { list[i].isGK = (i == idx); }
    });
    final p = list[idx];
    final name = team == 'home' ? _homeNameCtrl.text : _awayNameCtrl.text;
    _logEvent('🧤 Cambio Portiere', 'Va in porta #${p.num} ${p.name} ($name)', _getElapsedFormatted(), team: team);
  }

  Map<String, List<Map<String, dynamic>>> _calculateRatings() {
    final Map<String, List<Map<String, dynamic>>> res = {'home': [], 'away': []};
    final hWon = _homeScore > _awayScore;
    final aWon = _awayScore > _homeScore;

    for (final team in ['home', 'away']) {
      final teamWon = team == 'home' ? hWon : aWon;
      final teamLost = team == 'home' ? aWon : hWon;
      final list = team == 'home' ? _homePlayers : _awayPlayers;

      for (final p in list) {
        int goals = 0, assists = 0, fouls = 0, yellows = 0, reds = 0, penSaved = 0, penMissed = 0, ownGoals = 0, goalsConceded = 0, errors = 0, bigMisses = 0;
        for (final e in _events) {
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
          }
          if (e.type == 'GOL' && e.sub.contains('Assist: #${p.num} ${p.name}')) assists++;
          if ((e.type == 'GOL' || e.type == 'RIGORE_SEGNATO' || e.type == 'AUTOGOL') && e.gkConcededId == p.dbId) goalsConceded++;
        }

        final hasAction = (goals > 0 || assists > 0 || fouls > 0 || yellows > 0 || reds > 0 || penSaved > 0 || penMissed > 0 || ownGoals > 0 || goalsConceded > 0 || errors > 0 || bigMisses > 0);
        final playedEnough = p.playedSeconds >= 300;

        if (!hasAction && !playedEnough) {
          res[team]!.add({'num': p.num, 'name': p.name, 'score': 'S.V.', 'details': 'Meno di 5m e nessuna azione attiva'});
          continue;
        }

        double score = 6.0;
        final details = <String>[];

        if (teamWon) { score += 0.5; details.add('+0.5 vittoria'); } 
        else if (teamLost) { score -= 0.5; details.add('-0.5 sconfitta'); }

        if (goals > 0) { score += (goals * 1.0); details.add('+$goals gol'); }
        if (assists > 0) { score += (assists * 0.5); details.add('+${assists * 0.5} assist'); }
        if (penSaved > 0) { score += (penSaved * 1.5); details.add('+${penSaved * 1.5} rig. parato'); }
        if (penMissed > 0) { score -= (penMissed * 1.5); details.add('-${penMissed * 1.5} rig. sbagliato'); }
        if (ownGoals > 0) { score -= (ownGoals * 1.0); details.add('-$ownGoals autogol'); }
        if (yellows > 0) { score -= (yellows * 1.0); details.add('-$yellows giallo'); }
        if (reds > 0) { score -= (reds * 2.0); details.add('-${reds * 2} rosso'); }

        final foulMalus = (fouls ~/ 2) * 0.5;
        if (foulMalus > 0) { score -= foulMalus; details.add('-$foulMalus ($fouls falli)'); }

        final gkMalus = (goalsConceded ~/ 2) * 0.5;
        if (gkMalus > 0) { score -= gkMalus; details.add('-$gkMalus ($goalsConceded gol da POR)'); }

        if (p.gkPlayedSeconds >= 900 && goalsConceded == 0) {
          score += 1.0;
          details.add('+1.0 clean sheet (≥15m)');
        }

        final errMalus = (errors ~/ 2) * 0.5;
        if (errMalus > 0) { score -= errMalus; details.add('-$errMalus ($errors errori)'); }

        if (bigMisses > 0) {
          final missMalus = bigMisses * 0.5;
          score -= missMalus;
          details.add('-$missMalus ($bigMisses gol divorati)');
        }

        res[team]!.add({
          'num': p.num,
          'name': p.name,
          'score': score.clamp(1.0, 10.0).toStringAsFixed(1),
          'details': details.isNotEmpty ? details.join(', ') : 'Base 6.0',
        });
      }
    }
    return res;
  }

  void _openPlayerActionModal(String team, int idx) {
    final list = team == 'home' ? _homePlayers : _awayPlayers;
    final p = list[idx];
    final opposingTeamKey = team == 'home' ? 'away' : 'home';
    final opposingGK = _getCurrentGK(opposingTeamKey);
    final teamName = team == 'home' ? _homeNameCtrl.text : _awayNameCtrl.text;

    final nameController = TextEditingController(text: p.name);
    final numController = TextEditingController(text: p.num);
    String? selectedAssist;

    final potentialAssists = list.where((x) => x.dbId != p.dbId).toList();
    final benchTargets = list.where((x) => x.inField != p.inField).toList();
    MatchRosterPlayer? selectedSubTarget = benchTargets.isNotEmpty ? benchTargets.first : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚽ #${p.num} ${p.name} ($teamName)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: numController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(labelText: 'N°', filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(labelText: 'Nome Giocatore', filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedAssist,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(labelText: 'Assistito da (Opzionale)', filled: true, fillColor: const Color(0xFF1E293B), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Nessun Assist')),
                    ...potentialAssists.map((m) => DropdownMenuItem(value: '#${m.num} ${m.name}', child: Text('#${m.num} ${m.name}'))),
                  ],
                  onChanged: (val) => setMState(() => selectedAssist = val),
                ),
                const SizedBox(height: 14),

                // Griglia 10 Bottoni Azione Ridimensionata & Colori Uniformi
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 3.5,
                  children: [
                    _actionBtn('⚽ Gol', () { _triggerAction(team, p, 'GOL', assist: selectedAssist, opposingGK: opposingGK); Navigator.pop(ctx); }, textColor: const Color(0xFF10B981)),
                    _actionBtn('⭕ Autogol', () { _triggerAction(team, p, 'AUTOGOL', opposingGK: opposingGK); Navigator.pop(ctx); }, textColor: const Color(0xFFEF4444)),
                    _actionBtn('🟨 Giallo', () { _triggerAction(team, p, 'GIALLO'); Navigator.pop(ctx); }, textColor: const Color(0xFFF59E0B)),
                    _actionBtn('🟥 Rosso', () { _triggerAction(team, p, 'ROSSO'); Navigator.pop(ctx); }, textColor: const Color(0xFFEF4444)),
                    _actionBtn('👟 Rig. Seg.', () { _triggerAction(team, p, 'RIGORE_SEGNATO', opposingGK: opposingGK); Navigator.pop(ctx); }, textColor: const Color(0xFF10B981)),
                    _actionBtn('❌ Rig. Sbagl.', () { _triggerAction(team, p, 'RIGORE_SBAGLIATO'); Navigator.pop(ctx); }, textColor: const Color(0xFFEF4444)),
                    _actionBtn('🧤 Rig. Parato', () { _triggerAction(team, p, 'RIGORE_PARATO'); Navigator.pop(ctx); }, textColor: const Color(0xFF06B6D4)),
                    _actionBtn('🤦 Big Chance Missed', () { _triggerAction(team, p, 'BIG_CHANCE_MISSED'); Navigator.pop(ctx); }, textColor: const Color(0xFF94A3B8)),
                    _actionBtn('⚠️️ Fallo', () { _triggerAction(team, p, 'FALLO'); Navigator.pop(ctx); }, textColor: const Color(0xFF94A3B8)),
                    _actionBtn('📉 Errore', () { _triggerAction(team, p, 'ERRORE'); Navigator.pop(ctx); }, textColor: const Color(0xFF94A3B8)),
                  ],
                ),

                const SizedBox(height: 14),

                if (benchTargets.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF334155))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.inField ? 'SOSTITUISCI CON PANCHINARO:' : 'SCHIERA IN CAMPO AL POSTO DI:', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<MatchRosterPlayer>(
                                initialValue: selectedSubTarget,
                                dropdownColor: const Color(0xFF111827),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                items: benchTargets.map((t) => DropdownMenuItem(value: t, child: Text('#${t.num} ${t.name}'))).toList(),
                                onChanged: (v) => setMState(() => selectedSubTarget = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white),
                              onPressed: () {
                                if (selectedSubTarget != null) { _executeSubstitution(team, p, selectedSubTarget!); Navigator.pop(ctx); }
                              },
                              child: const Text('🔄 Cambia'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF334155))), child: const Text('Chiudi', style: TextStyle(color: Color(0xFF94A3B8))))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: const Color(0xFF042F22)),
                        onPressed: () {
                          setState(() { p.name = nameController.text.trim(); p.num = numController.text.trim(); });
                          Navigator.pop(ctx);
                        },
                        child: const Text('💾 Salva Info', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(String label, VoidCallback onTap, {Color textColor = Colors.white}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFF334155))),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
    );
  }

  void _triggerAction(String team, MatchRosterPlayer p, String type, {String? assist, MatchRosterPlayer? opposingGK}) {
    final teamName = team == 'home' ? _homeNameCtrl.text : _awayNameCtrl.text;
    final min = _getElapsedFormatted();
    final isPen = _currentPeriod == 5;

    setState(() {
      if (type == 'GOL' || type == 'RIGORE_SEGNATO') {
        if (isPen) {
          if (team == 'home') {
            _homePenalties++;
          } else {
            _awayPenalties++;
          }
          _logEvent(
            '👟 Rigore Segnato: #${p.num} ${p.name}',
            'Squadra: $teamName',
            min,
            team: team,
            isPenalty: true,
            type: 'RIGORE_SEGNATO',
            playerId: p.dbId,
          );
        } else {
          if (team == 'home') {
            _homeScore++;
          } else {
            _awayScore++;
          }
          var sub = 'Squadra: $teamName';
          if (assist != null && type == 'GOL') sub += ' • 🅰 Assist: $assist';
          if (opposingGK != null) sub += ' • (Gol subito: #${opposingGK.num} ${opposingGK.name})';
          _logEvent(
            type == 'GOL' ? '⚽ GOL! #${p.num} ${p.name}' : '👟 RIGORE! #${p.num} ${p.name}',
            sub,
            min,
            team: team,
            isPenalty: false,
            type: type,
            playerId: p.dbId,
            gkConcededId: opposingGK?.dbId,
          );
        }
      } else if (type == 'AUTOGOL') {
        final oppKey = team == 'home' ? 'away' : 'home';
        if (oppKey == 'home') {
          _homeScore++;
        } else {
          _awayScore++;
        }
        _logEvent(
          '⭕ AUTOGOL! #${p.num} ${p.name}',
          'A favore avversario (Autore: $teamName)',
          min,
          team: oppKey,
          isPenalty: isPen,
          type: 'AUTOGOL',
          playerId: p.dbId,
        );
      } else if (type == 'GIALLO') {
        _logEvent(
          '🟨 Ammonizione: #${p.num} ${p.name}',
          'Squadra: $teamName',
          min,
          team: team,
          isPenalty: isPen,
          type: 'GIALLO',
          playerId: p.dbId,
        );
      } else if (type == 'ROSSO') {
        _logEvent(
          '🟥 Espulsione: #${p.num} ${p.name}',
          'Squadra: $teamName',
          min,
          team: team,
          isPenalty: isPen,
          type: 'ROSSO',
          playerId: p.dbId,
        );
      } else if (type == 'RIGORE_PARATO') {
        _logEvent(
          '🧤 Rigore Parato da #${p.num} ${p.name}',
          'Squadra: $teamName',
          min,
          team: team,
          isPenalty: isPen, // <-- ORA È TRUE QUANDO _currentPeriod == 5
          type: 'RIGORE_PARATO',
          playerId: p.dbId,
        );
      } else if (type == 'RIGORE_SBAGLIATO') {
        _logEvent(
          '❌ Rigore Sbagliato da #${p.num} ${p.name}',
          'Squadra: $teamName',
          min,
          team: team,
          isPenalty: isPen, // <-- ORA È TRUE QUANDO _currentPeriod == 5
          type: 'RIGORE_SBAGLIATO',
          playerId: p.dbId,
        );
      } else if (type == 'FALLO') {
        _logEvent(
          '⚠️ Fallo di #${p.num} ${p.name}',
          'Squadra: $teamName',
          min,
          team: team,
          isPenalty: isPen,
          type: 'FALLO',
          playerId: p.dbId,
        );
      } else if (type == 'ERRORE') {
        _logEvent(
          '📉 Palla persa / Errore di #${p.num} ${p.name}',
          'Squadra: $teamName',
          min,
          team: team,
          isPenalty: isPen,
          type: 'ERRORE',
          playerId: p.dbId,
        );
      } else if (type == 'BIG_CHANCE_MISSED') {
        _logEvent(
          '🤦 Big Chance Missed da #${p.num} ${p.name}',
          'Squadra: $teamName',
          min,
          team: team,
          isPenalty: isPen,
          type: 'BIG_CHANCE_MISSED',
          playerId: p.dbId,
        );
      }
    });
  }

  void _executeSubstitution(String team, MatchRosterPlayer current, MatchRosterPlayer target) {
    setState(() {
      current.inField = !current.inField;
      target.inField = !target.inField;
      if (current.isGK && !current.inField) {
        current.isGK = false;
        target.isGK = true;
      }
    });
    final inP = current.inField ? current : target;
    final outP = current.inField ? target : current;
    final name = team == 'home' ? _homeNameCtrl.text : _awayNameCtrl.text;
    _logEvent('🔄 Sostituzione', 'Entra #${inP.num} ${inP.name}, Esce #${outP.num} ${outP.name} ($name)', _getElapsedFormatted(), team: team, type: 'SOSTITUZIONE');
  }

  void _openPagelleModal() {
    final ratings = _calculateRatings();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: const Text('⭐ Pagelle della Partita', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_homeNameCtrl.text.toUpperCase(), style: TextStyle(color: _homeColor, fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 4),
                ...ratings['home']!.map((r) => _pagellaTile(r)),
                const Divider(color: Color(0xFF334155), height: 20),
                Text(_awayNameCtrl.text.toUpperCase(), style: TextStyle(color: _awayColor, fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(height: 4),
                ...ratings['away']!.map((r) => _pagellaTile(r)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final hEmoji = _getTeamEmoji(_homeColor);
              final aEmoji = _getTeamEmoji(_awayColor);
              var text = '⭐ *PAGELLE MATCH*\n⚽ ${_homeNameCtrl.text} $_homeScore - $_awayScore ${_awayNameCtrl.text}\n\n';
              
              text += '$hEmoji *${_homeNameCtrl.text}*\n';
              for (final r in ratings['home']!) {
                text += '• _#${r['num']} ${r['name']}:_ *${r['score']}*\n';
              }
              
              text += '\n$aEmoji *${_awayNameCtrl.text}*\n';
              for (final r in ratings['away']!) {
                text += '• _#${r['num']} ${r['name']}:_ *${r['score']}*\n';
              }
              
              await Clipboard.setData(ClipboardData(text: text));
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pagelle copiate negli appunti!')));
              }
            },
            child: const Text('📋 Copia', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi', style: TextStyle(color: Color(0xFF94A3B8)))),
        ],
      ),
    );
  }

  Widget _pagellaTile(Map<String, dynamic> r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${r['num']} ${r['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(r['details'], style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: r['score'] == 'S.V.' ? const Color(0xFF334155) : const Color(0xFF10B981).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
            child: Text(r['score'], style: TextStyle(color: r['score'] == 'S.V.' ? const Color(0xFF94A3B8) : const Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // --- FUNZIONALITA' CONDIVISIONE ---
  void _shareCurrentMatch() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('📲 Condividi Tabellino', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Scegli quale formato di cronaca esportare:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: const Color(0xFF042F22), minimumSize: const Size.fromHeight(44)),
              onPressed: () { Navigator.pop(ctx); _processShare(true); },
              child: const Text('🌟 Solo Azioni Salienti\n(Gol, Rigori, Cartellini, Falli)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF334155)), foregroundColor: Colors.white, minimumSize: const Size.fromHeight(44)),
              onPressed: () { Navigator.pop(ctx); _processShare(false); },
              child: const Text('📜 Cronaca Completa\n(Include anche errori e cambi porta)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processShare(bool onlyHighlights) async {
    final hName = _homeNameCtrl.text;
    final aName = _awayNameCtrl.text;
    final hEmoji = _getTeamEmoji(_homeColor);
    final aEmoji = _getTeamEmoji(_awayColor);
    
    String text = '🏆 *TABELLINO MATCH: $hName vs $aName*\n';
    text += '⚽ $hEmoji $hName $_homeScore - $_awayScore $aName $aEmoji\n';
    if (_homePenalties > 0 || _awayPenalties > 0) text += '👟 Sequenza Rigori: $_homePenalties - $_awayPenalties\n';
    
    text += '\n👥 *FORMAZIONI:*\n';
    
    String formatLineup(String name, List<MatchRosterPlayer> roster, String emoji) {
      String block = '• $emoji *$name*\n  - In campo:\n';
      final inField = roster.where((p) => p.inField).toList();
      final bench = roster.where((p) => !p.inField).toList();
      if (inField.isEmpty) block += '    • Nessuno\n';
      for (var p in inField) {
        block += '    • #${p.num} ${p.name}${p.isGK ? ' (P)' : ''}\n';
      }
      block += '  - Panchina:\n';
      if (bench.isEmpty) block += '    • Nessuno\n';
      for (var p in bench) {
        block += '    • #${p.num} ${p.name}\n';
      }
      return block;
    }
    
    text += formatLineup(hName, _initialLineupHome ?? _homePlayers, hEmoji);
    text += formatLineup(aName, _initialLineupAway ?? _awayPlayers, aEmoji);
    
    text += onlyHighlights ? '\n📜 *AZIONI SALIENTI:*\n' : '\n📜 *CRONACA COMPLETA:*\n';
    
    final salienti = ['GOL', 'RIGORE_SEGNATO', 'RIGORE_SBAGLIATO', 'RIGORE_PARATO', 'AUTOGOL', 'GIALLO', 'ROSSO', 'FALLO', 'SOSTITUZIONE'];
    final filteredEvents = onlyHighlights ? _events.where((e) => salienti.contains(e.type)).toList() : _events.toList();
    
    if (filteredEvents.isEmpty) {
      text += '- Nessun evento registrato.\n';
    } else {
      for (var e in filteredEvents.reversed) {
        text += '• [${e.minute}] ${e.title} (${e.sub})\n';
      }
    }
    
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(onlyHighlights ? 'Tabellino (Azioni Salienti) copiato!' : 'Tabellino Completo copiato!')));
    }
  }

  Widget _numInput(TextEditingController ctrl, String suffix) {
    return Row(
      children: [
        SizedBox(
          width: 35, height: 26,
          child: TextField(
            controller: ctrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(contentPadding: EdgeInsets.zero, filled: true, fillColor: Color(0xFF1E293B), border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(4)))),
          ),
        ),
        const SizedBox(width: 2),
        Text(suffix, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeInField = _homePlayers.where((p) => p.inField).length;
    final awayInField = _awayPlayers.where((p) => p.inField).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header Timer Partita + Portiere a Giro
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF334155))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF334155))),
                          child: Text(_periodLabel.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF8B5CF6))),
                          child: Text('$homeInField vs $awayInField', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_timerMode == 'countdown' ? 'Conto alla Rovescia' : 'In Avanti', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      _currentPeriod == 5 ? '--:--' : _formatTime(_currentSeconds),
                      style: TextStyle(fontFamily: 'Courier', fontSize: 28, fontWeight: FontWeight.w900, color: (_timerMode == 'countdown' && _currentSeconds <= 10 && _currentSeconds > 0) ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF06B6D4))),
                      child: Column(
                        children: [
                          const Text('PORTA 🧤', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF06B6D4))),
                          Text(_formatTime(_gkCurrentSeconds), style: TextStyle(fontFamily: 'Courier', fontSize: 14, fontWeight: FontWeight.w900, color: _gkCurrentSeconds <= 15 ? const Color(0xFFEF4444) : const Color(0xFF06B6D4))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Configurazione Manuale Tempi
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E293B))),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Modalità Timer Partita:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        ChoiceChip(label: const Text('Rovescia ⏳', style: TextStyle(fontSize: 10)), selected: _timerMode == 'countdown', onSelected: (_) => _setTimerMode('countdown'), selectedColor: const Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        ChoiceChip(label: const Text('Avanti ⏱️', style: TextStyle(fontSize: 10)), selected: _timerMode == 'countup', onSelected: (_) => _setTimerMode('countup'), selectedColor: const Color(0xFF10B981)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Durata Tempo Partita:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        _numInput(_matchMinCtrl, 'm'), const SizedBox(width: 6), _numInput(_matchSecCtrl, 's'), const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0), minimumSize: const Size(0, 26)),
                          onPressed: _applyDurationSettings, child: const Text('Set', style: TextStyle(fontSize: 10, color: Colors.white)),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Timer Giro Porta:', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: _isGkRunning ? const Color(0xFFF59E0B) : const Color(0xFF06B6D4), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0), minimumSize: const Size(0, 26)),
                          onPressed: _toggleGkTimer, child: Text(_isGkRunning ? 'Pausa' : '▶ Avvia', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 4),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF334155)), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0), minimumSize: const Size(0, 26)),
                          onPressed: _resetGkTimer, child: const Text('Reset', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        ),
                        const SizedBox(width: 6),
                        _numInput(_gkMinCtrl, 'm'), const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0), minimumSize: const Size(0, 26)),
                          onPressed: _applyGkDurationSettings, child: const Text('Set', style: TextStyle(fontSize: 10, color: Colors.white)),
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Tabellone Punteggio Casa vs Ospiti
          Row(
            children: [
              Expanded(
                child: _teamScoreCard(
                  nameCtrl: _homeNameCtrl, score: _homeScore, penalties: _homePenalties, color: _homeColor,
                  onColorChange: (c) => setState(() => _homeColor = c), onGoal: () => _quickGoal('home'), onMinus: () => _promptMinusGoal('home'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _teamScoreCard(
                  nameCtrl: _awayNameCtrl, score: _awayScore, penalties: _awayPenalties, color: _awayColor,
                  onColorChange: (c) => setState(() => _awayColor = c), onGoal: () => _quickGoal('away'), onMinus: () => _promptMinusGoal('away'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Controlli Principali Timer e Reset
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _isMatchRunning ? const Color(0xFFF59E0B) : const Color(0xFF10B981), foregroundColor: const Color(0xFF042F22), padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: _toggleMatchTimer, icon: Icon(_isMatchRunning ? Icons.pause : Icons.play_arrow), label: Text(_isMatchRunning ? 'PAUSA' : 'AVVIA PARTITA', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFEF4444)), foregroundColor: const Color(0xFFEF4444), padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () {
                    setState(() {
                      _homeScore = 0; _awayScore = 0; _homePenalties = 0; _awayPenalties = 0; 
                      _events.clear(); _currentSeconds = _durationSeconds; _matchTimer?.cancel(); _isMatchRunning = false; _resetGkTimer();
                      _initialLineupHome = null; _initialLineupAway = null;
                      _setupInitialRosters();
                    });
                  },
                  child: const Text('RESET', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                 style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: _confirmEndMatch, child: const Text('FINE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Selettore Tempi
          Row(
            children: [
              _periodBtn(1, '1°T', '1° T'), _periodBtn(2, '2°T', '2° T'), _periodBtn(3, '1°TS', '1°TS'), _periodBtn(4, '2°TS', '2°TS'), _periodBtn(5, 'RIG', 'Rigori'),
            ],
          ),

          const SizedBox(height: 14),

          // Rose Giocatori
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _rosterColumn('home', _homeNameCtrl.text, _homeColor, _homePlayers)),
              const SizedBox(width: 8),
              Expanded(child: _rosterColumn('away', _awayNameCtrl.text, _awayColor, _awayPlayers)),
            ],
          ),

          const SizedBox(height: 14),

          // Feed Cronaca Live
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF334155))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CRONACA LIVE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
                    Text('${_events.length} Eventi', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ],
                ),
                const SizedBox(height: 8),
                if (_events.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: Text('Nessun evento registrato.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))))
                else
                  ..._events.map((e) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(e.sub, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Text(e.minute, style: const TextStyle(fontFamily: 'Courier', color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
                                const SizedBox(width: 6),
                                InkWell(onTap: () => _deleteEvent(e), child: const Icon(Icons.close, size: 14, color: Color(0xFFEF4444))),
                              ],
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tasto Pagelle & Condivisione (Stella Sistemata)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: const Color(0xFF042F22), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _openPagelleModal,
                  icon: const Icon(Icons.star),
                  label: const Text('PAGELLE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _shareCurrentMatch,
                  icon: const Icon(Icons.share),
                  label: const Text('CONDIVIDI', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teamScoreCard({
    required TextEditingController nameCtrl,
    required int score,
    required int penalties,
    required Color color,
    required ValueChanged<Color> onColorChange,
    required VoidCallback onGoal,
    required VoidCallback onMinus,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(14), border: Border(top: BorderSide(color: color, width: 4))),
      child: Column(
        children: [
          Row(
            children: [
              PopupMenuButton<Color>(
                icon: const Icon(Icons.circle, size: 18), color: const Color(0xFF1E293B), onSelected: onColorChange,
                itemBuilder: (ctx) => _colorOptions.entries.map((e) => PopupMenuItem(value: e.value, child: Text(e.key, style: const TextStyle(color: Colors.white, fontSize: 12)))).toList(),
              ),
              Expanded(child: TextField(controller: nameCtrl, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14), decoration: const InputDecoration(border: InputBorder.none, isDense: true))),
            ],
          ),
          Text('$score', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white)),
          if (penalties > 0 || _currentPeriod == 5) Text('(Rig: $penalties)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEAB308))),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(flex: 2, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: const Color(0xFF042F22), padding: const EdgeInsets.symmetric(vertical: 8)), onPressed: onGoal, child: const Text('⚽ +GOL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)))),
              const SizedBox(width: 4),
              Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF334155)), padding: const EdgeInsets.symmetric(vertical: 8)), onPressed: onMinus, child: const Text('-', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodBtn(int num, String shortLabel, String fullLabel) {
    final active = _currentPeriod == num;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(backgroundColor: active ? const Color(0xFF10B981) : const Color(0xFF111827), foregroundColor: active ? const Color(0xFF042F22) : const Color(0xFF94A3B8), side: BorderSide(color: active ? const Color(0xFF10B981) : const Color(0xFF334155)), padding: const EdgeInsets.symmetric(vertical: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          onPressed: () => _selectPeriod(num, fullLabel), child: Text(shortLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _rosterColumn(String teamKey, String title, Color borderCol, List<MatchRosterPlayer> roster) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border(top: BorderSide(color: borderCol, width: 3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: TextStyle(color: borderCol, fontWeight: FontWeight.w900, fontSize: 11)),
          const SizedBox(height: 6),
          ...roster.asMap().entries.map((entry) {
            final idx = entry.key;
            final p = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(color: p.inField ? const Color(0xFF1E293B) : const Color(0xFF0F172A), borderRadius: BorderRadius.circular(6), border: Border.all(color: p.inField ? const Color(0xFF334155) : const Color(0xFF1E293B))),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _openPlayerActionModal(teamKey, idx),
                      child: Text('#${p.num} ${p.name}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: p.inField ? Colors.white : const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  InkWell(
                    onTap: () => _setGoalkeeper(teamKey, idx),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: p.isGK ? const Color(0xFF06B6D4).withValues(alpha: 0.2) : Colors.transparent, borderRadius: BorderRadius.circular(4)), child: Text('POR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: p.isGK ? const Color(0xFF06B6D4) : const Color(0xFF64748B)))),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => p.inField = !p.inField),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: p.inField ? const Color(0xFF10B981).withValues(alpha: 0.2) : Colors.transparent, borderRadius: BorderRadius.circular(4)), child: Text(p.inField ? 'IN' : 'OUT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: p.inField ? const Color(0xFF10B981) : const Color(0xFF64748B)))),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _removePlayerFromRoster(teamKey, idx),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: const Icon(Icons.close, size: 14, color: Color(0xFFEF4444))),
                  ),
                ],
              ),
            );
          }),
          
          const SizedBox(height: 6),
          // RIGA AGGIUNTA GIOCATORI ON THE GO
          Row(
            children: [
              SizedBox(
                width: 30,
                height: 28,
                child: TextField(
                  controller: teamKey == 'home' ? _addNumHomeCtrl : _addNumAwayCtrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: '#', hintStyle: TextStyle(color: Color(0xFF64748B)),
                    contentPadding: EdgeInsets.zero,
                    filled: true, fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: TextField(
                    controller: teamKey == 'home' ? _addNameHomeCtrl : _addNameAwayCtrl,
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: 'Nome', hintStyle: TextStyle(color: Color(0xFF64748B)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 6),
                      filled: true, fillColor: Color(0xFF1E293B),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _addPlayerToRoster(teamKey),
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4)),
                  alignment: Alignment.center,
                  child: const Text('+', style: TextStyle(color: Color(0xFF042F22), fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}