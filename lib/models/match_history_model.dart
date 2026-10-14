import 'match_roster_player.dart';
import 'match_event_model.dart';

class MatchHistoryModel {
  final String id;
  final String title;
  final String date;
  final String homeName;
  final String awayName;
  final int homeScore;
  final int awayScore;
  final int homePenalties;
  final int awayPenalties;
  final int homeColorValue;
  final int awayColorValue;
  final List<MatchRosterPlayer> homeRoster;
  final List<MatchRosterPlayer> awayRoster;
  final List<MatchEventModel> events;
  final String? tournamentId; // <-- OPZIONALE: se è null è un'Amichevole!

  MatchHistoryModel({
    required this.id,
    required this.title,
    required this.date,
    required this.homeName,
    required this.awayName,
    required this.homeScore,
    required this.awayScore,
    required this.homePenalties,
    required this.awayPenalties,
    required this.homeColorValue,
    required this.awayColorValue,
    required this.homeRoster,
    required this.awayRoster,
    required this.events,
    this.tournamentId, // <-- NON è required, quindi non dà errori nello Scoreboard!
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date,
        'homeName': homeName,
        'awayName': awayName,
        'homeScore': homeScore,
        'awayScore': awayScore,
        'homePenalties': homePenalties,
        'awayPenalties': awayPenalties,
        'homeColorValue': homeColorValue,
        'awayColorValue': awayColorValue,
        'homeRoster': homeRoster.map((e) => e.toJson()).toList(),
        'awayRoster': awayRoster.map((e) => e.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'tournamentId': tournamentId,
      };

  factory MatchHistoryModel.fromJson(Map<String, dynamic> json) => MatchHistoryModel(
        id: json['id'] as String,
        title: json['title'] as String,
        date: json['date'] as String,
        homeName: json['homeName'] as String,
        awayName: json['awayName'] as String,
        homeScore: json['homeScore'] as int,
        awayScore: json['awayScore'] as int,
        homePenalties: json['homePenalties'] as int? ?? 0,
        awayPenalties: json['awayPenalties'] as int? ?? 0,
        homeColorValue: json['homeColorValue'] as int? ?? 0xFF3B82F6,
        awayColorValue: json['awayColorValue'] as int? ?? 0xFFEF4444,
        homeRoster: (json['homeRoster'] as List<dynamic>?)
                ?.map((e) => MatchRosterPlayer.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        awayRoster: (json['awayRoster'] as List<dynamic>?)
                ?.map((e) => MatchRosterPlayer.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        events: (json['events'] as List<dynamic>?)
                ?.map((e) => MatchEventModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        tournamentId: json['tournamentId'] as String?,
      );
}