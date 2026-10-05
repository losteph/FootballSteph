class MatchRosterPlayer {
  final String dbId;
  String num;
  String name;
  bool inField;
  bool isGK;
  int playedSeconds;
  int gkPlayedSeconds;

  MatchRosterPlayer({
    required this.dbId,
    required this.num,
    required this.name,
    this.inField = true,
    this.isGK = false,
    this.playedSeconds = 0,
    this.gkPlayedSeconds = 0,
  });

  Map<String, dynamic> toJson() => {
        'dbId': dbId,
        'num': num,
        'name': name,
        'inField': inField,
        'isGK': isGK,
        'playedSeconds': playedSeconds,
        'gkPlayedSeconds': gkPlayedSeconds,
      };

  factory MatchRosterPlayer.fromJson(Map<String, dynamic> json) =>
      MatchRosterPlayer(
        dbId: json['dbId'] ?? '',
        num: json['num'] ?? '?',
        name: json['name'] ?? '',
        inField: json['inField'] ?? true,
        isGK: json['isGK'] ?? false,
        playedSeconds: json['playedSeconds'] ?? 0,
        gkPlayedSeconds: json['gkPlayedSeconds'] ?? 0,
      );
}