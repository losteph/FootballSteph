import '../models/player_model.dart';

class MatchTeams {
  final List<PlayerModel> team1;
  final List<PlayerModel> team2;

  MatchTeams({required this.team1, required this.team2});

  double get avgOvr1 => team1.isEmpty
      ? 0.0
      : team1.fold(0.0, (acc, p) => acc + p.ovrData.numeric) / team1.length;

  double get avgOvr2 => team2.isEmpty
      ? 0.0
      : team2.fold(0.0, (acc, p) => acc + p.ovrData.numeric) / team2.length;
}

class TeamBalancer {
  // Calcola il punteggio numerico di una singola statistica (default 60 se assente)
  static double _getStatVal(PlayerModel p, String statKey) {
    final grade = p.stats[statKey];
    if (grade == null) return 60.0;
    return (PlayerModel.gradeMap[grade] ?? 60).toDouble();
  }

  // Calcola il dislivello tra due squadre considerando OVR e singole statistiche
  static double _calcImbalanceScore(List<PlayerModel> t1, List<PlayerModel> t2) {
    if (t1.isEmpty || t2.isEmpty) return 999999.0;

    final ovr1 = t1.fold(0.0, (acc, p) => acc + p.ovrData.numeric);
    final ovr2 = t2.fold(0.0, (acc, p) => acc + p.ovrData.numeric);
    double totalImbalance = (ovr1 - ovr2).abs() * 1.5; // Peso primario: OVR totale

    // Elenco statistiche di campo e porta da comparare
    const subStats = ['vel', 'tir', 'pas', 'dri', 'dif', 'fis', 'tuf', 'pre', 'rin', 'rif', 'pia'];
    for (final s in subStats) {
      final s1 = t1.fold(0.0, (acc, p) => acc + _getStatVal(p, s));
      final s2 = t2.fold(0.0, (acc, p) => acc + _getStatVal(p, s));
      totalImbalance += (s1 - s2).abs() * 0.35; // Peso secondario: equilibrio per singola caratteristica
    }

    return totalImbalance;
  }

  static MatchTeams balanceTeams(List<PlayerModel> pool) {
    if (pool.isEmpty) return MatchTeams(team1: [], team2: []);

    final int targetTeamSize = (pool.length / 2).ceil();
    final List<PlayerModel> t1 = [];
    final List<PlayerModel> t2 = [];

    // 1. Raggruppa i convocati per ruolo
    final porList = pool.where((p) => p.role == PlayerRole.POR).toList()
      ..sort((a, b) => b.ovrData.numeric.compareTo(a.ovrData.numeric));
    final difList = pool.where((p) => p.role == PlayerRole.DIF).toList()
      ..sort((a, b) => b.ovrData.numeric.compareTo(a.ovrData.numeric));
    final cenList = pool.where((p) => p.role == PlayerRole.CEN).toList()
      ..sort((a, b) => b.ovrData.numeric.compareTo(a.ovrData.numeric));
    final attList = pool.where((p) => p.role == PlayerRole.ATT).toList()
      ..sort((a, b) => b.ovrData.numeric.compareTo(a.ovrData.numeric));

    // 2. Distribuzione a blocchi (Portieri -> Difensori -> Centrocampisti -> Attaccanti)
    final orderedGroups = [porList, difList, cenList, attList];

    for (final group in orderedGroups) {
      for (final player in group) {
        if (t1.length >= targetTeamSize) {
          t2.add(player);
          continue;
        }
        if (t2.length >= targetTeamSize) {
          t1.add(player);
          continue;
        }

        final countRole1 = t1.where((p) => p.role == player.role).length;
        final countRole2 = t2.where((p) => p.role == player.role).length;

        if (countRole1 < countRole2) {
          t1.add(player);
        } else if (countRole2 < countRole1) {
          t2.add(player);
        } else {
          // Valuta l'impatto inserendo virtualmente il giocatore su t1 o t2
          final scoreIfIn1 = _calcImbalanceScore([...t1, player], t2.isEmpty ? [player] : t2);
          final scoreIfIn2 = _calcImbalanceScore(t1.isEmpty ? [player] : t1, [...t2, player]);
          if (scoreIfIn1 <= scoreIfIn2) {
            t1.add(player);
          } else {
            t2.add(player);
          }
        }
      }
    }

    // 3. Ottimizzazione Intra-Ruolo multi-stat
    bool improved = true;
    while (improved) {
      improved = false;
      double currentCost = _calcImbalanceScore(t1, t2);

      for (int i = 0; i < t1.length; i++) {
        for (int j = 0; j < t2.length; j++) {
          if (t1[i].role == t2[j].role) {
            final simT1 = List<PlayerModel>.from(t1);
            final simT2 = List<PlayerModel>.from(t2);

            simT1[i] = t2[j];
            simT2[j] = t1[i];

            final simCost = _calcImbalanceScore(simT1, simT2);

            if (simCost < currentCost - 0.1) {
              final temp = t1[i];
              t1[i] = t2[j];
              t2[j] = temp;
              currentCost = simCost;
              improved = true;
              break;
            }
          }
        }
        if (improved) break;
      }
    }

    return MatchTeams(team1: t1, team2: t2);
  }
}