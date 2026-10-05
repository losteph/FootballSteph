class MatchEventModel {
  final int id;
  final String title;
  final String sub;
  final String minute;
  final String? team; // 'home' o 'away'
  final bool isPenalty;
  final String type; // 'GOL', 'GIALLO', 'ROSSO', ecc.
  final String? playerId;
  final String? gkConcededId;

  MatchEventModel({
    required this.id,
    required this.title,
    required this.sub,
    required this.minute,
    this.team,
    this.isPenalty = false,
    this.type = 'OTHER',
    this.playerId,
    this.gkConcededId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sub': sub,
        'minute': minute,
        'team': team,
        'isPenalty': isPenalty,
        'type': type,
        'playerId': playerId,
        'gkConcededId': gkConcededId,
      };

  factory MatchEventModel.fromJson(Map<String, dynamic> json) => MatchEventModel(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch,
        title: json['title'] ?? '',
        sub: json['sub'] ?? '',
        minute: json['minute'] ?? '',
        team: json['team'],
        isPenalty: json['isPenalty'] ?? false,
        type: json['type'] ?? 'OTHER',
        playerId: json['playerId']?.toString(),
        gkConcededId: json['gkConcededId']?.toString(),
      );
}