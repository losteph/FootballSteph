import 'match_roster_player.dart';
import 'match_event_model.dart';

class MatchHistoryModel {
  final String id;
  String title;
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
        'homeRoster': homeRoster.map((p) => p.toJson()).toList(),
        'awayRoster': awayRoster.map((p) => p.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
      };

  factory MatchHistoryModel.fromJson(Map<String, dynamic> json) => MatchHistoryModel(
        id: json['id'].toString(),
        title: json['title'] ?? 'Partita',
        date: json['date'] ?? '',
        homeName: json['homeName'] ?? 'CASA',
        awayName: json['awayName'] ?? 'OSPITI',
        homeScore: json['homeScore'] ?? 0,
        awayScore: json['awayScore'] ?? 0,
        homePenalties: json['homePenalties'] ?? 0,
        awayPenalties: json['awayPenalties'] ?? 0,
        homeColorValue: json['homeColorValue'] ?? 0xFF3B82F6,
        awayColorValue: json['awayColorValue'] ?? 0xFFEF4444,
        homeRoster: (json['homeRoster'] as List?)?.map((item) => MatchRosterPlayer.fromJson(item)).toList() ?? [],
        awayRoster: (json['awayRoster'] as List?)?.map((item) => MatchRosterPlayer.fromJson(item)).toList() ?? [],
        events: (json['events'] as List?)?.map((item) => MatchEventModel.fromJson(item)).toList() ?? [],
      );
}