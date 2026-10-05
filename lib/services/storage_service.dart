import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_model.dart';
import '../models/match_history_model.dart';

class StorageService {
  static const String _playersKey = 'calcetto_pro_players';
  static const String _matchesKey = 'calcetto_pro_matches';

  static final List<PlayerModel> defaultPlayers = [
    PlayerModel(id: '1', name: 'Buffon', role: PlayerRole.POR, stats: {'tuf': 'A+', 'pre': 'A', 'rin': 'B+', 'rif': 'A+', 'vel': 'B-', 'pia': 'A+'}),
    PlayerModel(id: '2', name: 'Peruzzi', role: PlayerRole.POR, stats: {'tuf': 'A-', 'pre': 'A-', 'rin': 'B', 'rif': 'A', 'vel': 'B', 'pia': 'A-'}),
    PlayerModel(id: '3', name: 'Maldini', role: PlayerRole.DIF, stats: {'vel': 'A-', 'tir': 'B-', 'pas': 'B+', 'dri': 'B+', 'dif': 'A+', 'fis': 'A'}),
    PlayerModel(id: '4', name: 'Nesta', role: PlayerRole.DIF, stats: {'vel': 'B+', 'tir': 'C+', 'pas': 'B', 'dri': 'B', 'dif': 'A+', 'fis': 'A'}),
    PlayerModel(id: '5', name: 'Cannavaro', role: PlayerRole.DIF, stats: {'vel': 'A-', 'tir': 'C', 'pas': 'B-', 'dri': 'B-', 'dif': 'A+', 'fis': 'A+'}),
    PlayerModel(id: '6', name: 'Chiellini', role: PlayerRole.DIF, stats: {'vel': 'B', 'tir': 'C-', 'pas': 'C+', 'dri': 'C+', 'dif': 'A', 'fis': 'A+'}),
    PlayerModel(id: '7', name: 'Pirlo', role: PlayerRole.CEN, stats: {'vel': 'C+', 'tir': 'A-', 'pas': 'A+', 'dri': 'A', 'dif': 'B-', 'fis': 'B-'}),
    PlayerModel(id: '8', name: 'Gattuso', role: PlayerRole.CEN, stats: {'vel': 'B+', 'tir': 'C+', 'pas': 'B-', 'dri': 'C+', 'dif': 'A+', 'fis': 'A+'}),
    PlayerModel(id: '9', name: 'De Rossi', role: PlayerRole.CEN, stats: {'vel': 'B', 'tir': 'B+', 'pas': 'A-', 'dri': 'B', 'dif': 'A-', 'fis': 'A'}),
    PlayerModel(id: '10', name: 'Totti', role: PlayerRole.ATT, stats: {'vel': 'B+', 'tir': 'A+', 'pas': 'A+', 'dri': 'A+', 'dif': 'C', 'fis': 'A-'}),
    PlayerModel(id: '11', name: 'Del Piero', role: PlayerRole.ATT, stats: {'vel': 'A-', 'tir': 'A+', 'pas': 'A', 'dri': 'A+', 'dif': 'C-', 'fis': 'B'}),
    PlayerModel(id: '12', name: 'Baggio', role: PlayerRole.ATT, stats: {'vel': 'A-', 'tir': 'A+', 'pas': 'A+', 'dri': 'A+', 'dif': 'C-', 'fis': 'B-'}),
    PlayerModel(id: '13', name: 'Inzaghi', role: PlayerRole.ATT, stats: {'vel': 'A-', 'tir': 'A', 'pas': 'C', 'dri': 'B-', 'dif': 'C-', 'fis': 'B+'}),
    PlayerModel(id: '14', name: 'Vieri', role: PlayerRole.ATT, stats: {'vel': 'B+', 'tir': 'A+', 'pas': 'B-', 'dri': 'B', 'dif': 'C', 'fis': 'A+'}),
  ];

  static Future<List<PlayerModel>> loadPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_playersKey);
    if (raw == null || raw.isEmpty) {
      await savePlayers(defaultPlayers);
      return List.from(defaultPlayers);
    }
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((item) => PlayerModel.fromJson(item)).toList();
    } catch (e) {
      return List.from(defaultPlayers);
    }
  }

  static Future<void> savePlayers(List<PlayerModel> players) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = players.map((p) => p.toJson()).toList();
    await prefs.setString(_playersKey, jsonEncode(jsonList));
  }

  static Future<List<MatchHistoryModel>> loadMatches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_matchesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((item) => MatchHistoryModel.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveMatch(MatchHistoryModel newMatch) async {
    final prefs = await SharedPreferences.getInstance();
    final List<MatchHistoryModel> currentMatches = await loadMatches();
    currentMatches.insert(0, newMatch);
    await prefs.setString(_matchesKey, jsonEncode(currentMatches.map((m) => m.toJson()).toList()));
  }

  static Future<void> deleteMatch(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<MatchHistoryModel> currentMatches = await loadMatches();
    currentMatches.removeWhere((m) => m.id == matchId);
    await prefs.setString(_matchesKey, jsonEncode(currentMatches.map((m) => m.toJson()).toList()));
  }

  // ============================================================
  // EXPORT / IMPORT JSON
  // Compatibile con file_picker 13.x
  // ============================================================

  // ------------------------------------------------------------
  // EXPORT GIOCATORI
  // ------------------------------------------------------------
  static Future<bool> exportPlayersToFile(
    List<PlayerModel> players,
  ) async {
    try {
      final jsonStr = const JsonEncoder.withIndent('  ').convert(
        players.map((p) => p.toJson()).toList(),
      );

      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      final result = await FilePicker.saveFile(
        dialogTitle: 'Salva backup giocatori',
        fileName: 'database_giocatori.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
        mimeType: 'application/json',
      );

      // null = utente ha annullato
      return result != null;
    } catch (e) {
      return false;
    }
  }

  // ------------------------------------------------------------
  // EXPORT PARTITE
  // ------------------------------------------------------------
  static Future<bool> exportMatchesToFile(
    List<MatchHistoryModel> matches,
  ) async {
    try {
      final jsonStr = const JsonEncoder.withIndent('  ').convert(
        matches.map((m) => m.toJson()).toList(),
      );

      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      final result = await FilePicker.saveFile(
        dialogTitle: 'Salva backup partite',
        fileName: 'storico_partite.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
        mimeType: 'application/json',
      );

      // null = utente ha annullato
      return result != null;
    } catch (e) {
      return false;
    }
  }

  // ------------------------------------------------------------
  // IMPORT GIOCATORI - MERGE
  // ------------------------------------------------------------
  static Future<bool> pickAndImportPlayersMerge() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      // Utente ha annullato
      if (file == null) {
        return false;
      }

      // file_picker 13: lettura tramite readAsBytes()
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        return false;
      }

      final content = utf8.decode(bytes);
      final decoded = jsonDecode(content);

      if (decoded is! List) {
        return false;
      }

      final newPlayers = decoded
          .map(
            (item) => PlayerModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      final existing = await loadPlayers();

      // Aggiunge solamente i giocatori che non esistono già.
      for (final player in newPlayers) {
        final alreadyExists = existing.any(
          (existingPlayer) => existingPlayer.id == player.id,
        );

        if (!alreadyExists) {
          existing.add(player);
        }
      }

      await savePlayers(existing);

      return true;
    } catch (e) {
      return false;
    }
  }

  // ------------------------------------------------------------
  // IMPORT PARTITE - MERGE
  // ------------------------------------------------------------
  static Future<bool> pickAndImportMatchesMerge() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      // Utente ha annullato
      if (file == null) {
        return false;
      }

      // file_picker 13: lettura tramite readAsBytes()
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        return false;
      }

      final content = utf8.decode(bytes);
      final decoded = jsonDecode(content);

      if (decoded is! List) {
        return false;
      }

      final newMatches = decoded
          .map(
            (item) => MatchHistoryModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      final existing = await loadMatches();

      // Aggiunge solamente le partite che non esistono già.
      for (final match in newMatches) {
        final alreadyExists = existing.any(
          (existingMatch) => existingMatch.id == match.id,
        );

        if (!alreadyExists) {
          existing.add(match);
        }
      }

      // Mantiene l'ordine dal più recente al più vecchio.
      existing.sort(
        (a, b) => b.id.compareTo(a.id),
      );

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _matchesKey,
        jsonEncode(
          existing.map((m) => m.toJson()).toList(),
        ),
      );

      return true;
    } catch (e) {
      return false;
    }
  }
}