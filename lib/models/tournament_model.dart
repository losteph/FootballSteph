class TournamentModel {
  final String id;
  String name;
  List<String> teamIds; // ID delle squadre iscritte al torneo
  final DateTime createdAt;

  TournamentModel({
    required this.id,
    required this.name,
    required this.teamIds,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'teamIds': teamIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TournamentModel.fromJson(Map<String, dynamic> json) => TournamentModel(
        id: json['id'] as String,
        name: json['name'] as String,
        teamIds: (json['teamIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

class LeagueTableRow {
  final String teamId;
  final String teamName;
  final int teamColorValue;
  int played = 0;       // G (Giocate)
  int won = 0;          // V (Vinte)
  int drawn = 0;        // N (Nulle/Pareggiate)
  int lost = 0;         // S (Sconfitte)
  int goalsFor = 0;     // GF (Gol Fatti)
  int goalsAgainst = 0; // GS (Gol Subiti)

  LeagueTableRow({
    required this.teamId,
    required this.teamName,
    required this.teamColorValue,
  });

  int get points => (won * 3) + (drawn * 1);
  int get goalDifference => goalsFor - goalsAgainst; // DR
}