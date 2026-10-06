import 'package:flutter/material.dart';

enum PlayerRole { POR, DIF, CEN, ATT }

enum CardTier { gold, silver, bronze }

class OvrData {
  final int numeric;
  final String letter;
  final CardTier tier;

  OvrData({required this.numeric, required this.letter, required this.tier});
}

class PlayerModel {
  final String id;
  String name;
  PlayerRole role;
  Map<String, String> stats; // Es. {'vel': 'A', 'tir': 'B+', ...}

  PlayerModel({
    required this.id,
    required this.name,
    required this.role,
    required this.stats,
  });

  // Mappa di conversione voti a punteggio numerico
  static const Map<String, int> gradeMap = {
    'C-': 55, 'C': 62, 'C+': 67,
    'B-': 72, 'B': 77, 'B+': 82,
    'A-': 87, 'A': 92, 'A+': 99,
  };

  // Statistiche per ruolo
  static const List<Map<String, String>> porStatDefs = [
    {'id': 'tuf', 'label': 'TUF'},
    {'id': 'pre', 'label': 'PRE'},
    {'id': 'rin', 'label': 'RIN'},
    {'id': 'rif', 'label': 'RIF'},
    {'id': 'vel', 'label': 'VEL'},
    {'id': 'pia', 'label': 'PIA'},
  ];

  static const List<Map<String, String>> fieldStatDefs = [
    {'id': 'vel', 'label': 'VEL'},
    {'id': 'tir', 'label': 'TIR'},
    {'id': 'pas', 'label': 'PAS'},
    {'id': 'dri', 'label': 'DRI'},
    {'id': 'dif', 'label': 'DIF'},
    {'id': 'fis', 'label': 'FIS'},
  ];

  // Calcolo OVR, Lettera e Fascia Metallo
  OvrData get ovrData {
    if (stats.isEmpty) {
      return OvrData(numeric: 60, letter: 'C', tier: CardTier.bronze);
    }

    int sum = 0;
    stats.forEach((_, grade) {
      sum += gradeMap[grade] ?? 60;
    });

    final int numeric = (sum / stats.length).round();
    String letter = 'C';
    CardTier tier = CardTier.bronze;

    if (numeric >= 95) {
      letter = 'A+';
      tier = CardTier.gold;
    } else if (numeric >= 90) {
      letter = 'A';
      tier = CardTier.gold;
    } else if (numeric >= 85) {
      letter = 'A-';
      tier = CardTier.gold;
    } else if (numeric >= 80) {
      letter = 'B+';
      tier = CardTier.silver;
    } else if (numeric >= 75) {
      letter = 'B';
      tier = CardTier.silver;
    } else if (numeric >= 70) {
      letter = 'B-';
      tier = CardTier.silver;
    } else if (numeric >= 65) {
      letter = 'C+';
      tier = CardTier.bronze;
    } else if (numeric >= 60) {
      letter = 'C';
      tier = CardTier.bronze;
    } else {
      letter = 'C-';
      tier = CardTier.bronze;
    }

    return OvrData(numeric: numeric, letter: letter, tier: tier);
  }

  // Colore del ruolo per i badge
  Color get roleColor {
    switch (role) {
      case PlayerRole.POR:
        return const Color(0xFFEAB308); // Giallo
      case PlayerRole.DIF:
        return const Color(0xFF10B981); // Verde
      case PlayerRole.CEN:
        return const Color(0xFF3B82F6); // Blu
      case PlayerRole.ATT:
        return const Color(0xFFF43F5E); // Rosso/Rosa
    }
  }

  // Serializzazione JSON per salvataggio e backup
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.name,
        'stats': stats,
      };

  factory PlayerModel.fromJson(Map<String, dynamic> json) => PlayerModel(
        id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] ?? '',
        role: PlayerRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => PlayerRole.CEN,
        ),
        stats: Map<String, String>.from(json['stats'] ?? {}),
      );
}