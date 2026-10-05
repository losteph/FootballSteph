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

    // 2. Distribuzione a blocchi (Portieri prima, poi Difensori, Centrocampisti, Attaccanti)
    final orderedGroups = [porList, difList, cenList, attList];

    for (final group in orderedGroups) {
      for (final player in group) {
        // Vincolo ferreo sul numero: se una squadra è già al completo, l'atleta va all'altra
        if (t1.length >= targetTeamSize) {
          t2.add(player);
          continue;
        }
        if (t2.length >= targetTeamSize) {
          t1.add(player);
          continue;
        }

        // Se entrambe hanno posto, bilancia prima per ruolo e poi per somma OVR
        final countRole1 = t1.where((p) => p.role == player.role).length;
        final countRole2 = t2.where((p) => p.role == player.role).length;

        if (countRole1 < countRole2) {
          t1.add(player);
        } else if (countRole2 < countRole1) {
          t2.add(player);
        } else {
          final sum1 = t1.fold(0.0, (acc, p) => acc + p.ovrData.numeric);
          final sum2 = t2.fold(0.0, (acc, p) => acc + p.ovrData.numeric);
          if (sum1 <= sum2) {
            t1.add(player);
          } else {
            t2.add(player);
          }
        }
      }
    }

    // 3. Ottimizzazione Globale a Scambi Intra-Ruolo (senza mai toccare la numerosità)
    bool improved = true;
    while (improved) {
      improved = false;
      double currentDiff = (t1.fold(0.0, (a, p) => a + p.ovrData.numeric) -
                            t2.fold(0.0, (a, p) => a + p.ovrData.numeric)).abs();

      for (int i = 0; i < t1.length; i++) {
        for (int j = 0; j < t2.length; j++) {
          // Si possono scambiare solo giocatori dello stesso ruolo per mantenere intatta la struttura
          if (t1[i].role == t2[j].role) {
            final simSum1 = t1.fold(0.0, (a, p) => a + p.ovrData.numeric) - t1[i].ovrData.numeric + t2[j].ovrData.numeric;
            final simSum2 = t2.fold(0.0, (a, p) => a + p.ovrData.numeric) - t2[j].ovrData.numeric + t1[i].ovrData.numeric;
            final simDiff = (simSum1 - simSum2).abs();

            if (simDiff < currentDiff - 0.05) {
              final temp = t1[i];
              t1[i] = t2[j];
              t2[j] = temp;
              currentDiff = simDiff;
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