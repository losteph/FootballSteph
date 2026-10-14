class TeamPlayerEntry {
  final String playerId;
  bool isStarter; // true = Titolare (IN), false = Panchina (OUT)
  String? customNum; // Numero di maglia personalizzato

  TeamPlayerEntry({
    required this.playerId,
    this.isStarter = true,
    this.customNum,
  });

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'isStarter': isStarter,
        'customNum': customNum,
      };

  factory TeamPlayerEntry.fromJson(Map<String, dynamic> json) => TeamPlayerEntry(
        playerId: json['playerId'] as String,
        isStarter: json['isStarter'] as bool? ?? true,
        customNum: json['customNum'] as String?,
      );
}

class TeamModel {
  final String id;
  String name;
  int colorValue;
  List<TeamPlayerEntry> roster;

  TeamModel({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.roster,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'roster': roster.map((e) => e.toJson()).toList(),
      };

  factory TeamModel.fromJson(Map<String, dynamic> json) => TeamModel(
        id: json['id'] as String,
        name: json['name'] as String,
        colorValue: json['colorValue'] as int,
        roster: (json['roster'] as List<dynamic>?)
                ?.map((e) => TeamPlayerEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}