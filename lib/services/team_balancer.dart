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
    final List<PlayerModel> t1 = [];
    final List<PlayerModel> t2 = [];

    const rolesOrder = [
      PlayerRole.POR,
      PlayerRole.DIF,
      PlayerRole.CEN,
      PlayerRole.ATT,
    ];

    for (final role in rolesOrder) {
      final roleGroup = pool.where((p) => p.role == role).toList()
        ..sort((a, b) => b.ovrData.numeric.compareTo(a.ovrData.numeric));

      for (final player in roleGroup) {
        final sum1 = t1.fold(0, (acc, p) => acc + p.ovrData.numeric);
        final sum2 = t2.fold(0, (acc, p) => acc + p.ovrData.numeric);

        if (t1.length <= t2.length && sum1 <= sum2) {
          t1.add(player);
        } else {
          t2.add(player);
        }
      }
    }

    return MatchTeams(team1: t1, team2: t2);
  }
}