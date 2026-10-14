import 'package:flutter/material.dart';
import 'screens/database_screen.dart';
import 'screens/squad_builder_screen.dart';
import 'models/match_roster_player.dart';
import 'screens/scoreboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/teams_screen.dart';

void main() {
  runApp(const StephCalcettoApp());
}

class StephCalcettoApp extends StatelessWidget {
  const StephCalcettoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calcetto Pro Suite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        primaryColor: const Color(0xFF10B981),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          surface: Color(0xFF111827),
          surfaceContainerHighest: Color(0xFF1E293B),
        ),
        fontFamily: 'Segoe UI',
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;


  List<MatchRosterPlayer> _liveHomePlayers = [];
  List<MatchRosterPlayer> _liveAwayPlayers = [];
  String _liveHomeName = 'CASA';
  String _liveAwayName = 'OSPITI';
  Color _liveHomeColor = const Color(0xFF3B82F6);
  Color _liveAwayColor = const Color(0xFFEF4444);

  final GlobalKey<SquadBuilderScreenState> _squadKey = GlobalKey<SquadBuilderScreenState>();
  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();

  void _handleSquadsToMatch(List<MatchRosterPlayer> home, List<MatchRosterPlayer> away) {
    setState(() {
      _liveHomePlayers = home;
      _liveAwayPlayers = away;
      _liveHomeName = 'CASA';
      _liveAwayName = 'OSPITI';
      _liveHomeColor = const Color(0xFF3B82F6);
      _liveAwayColor = const Color(0xFFEF4444);
      _currentIndex = 3; // Passa subito alla tab 3 (Scoreboard)
    });
  }

  void _handleTeamsToMatch(
    List<MatchRosterPlayer> home,
    List<MatchRosterPlayer> away,
    String homeName,
    String awayName,
    Color homeColor,
    Color awayColor,
  ) {
    setState(() {
      _liveHomePlayers = home;
      _liveAwayPlayers = away;
      _liveHomeName = homeName;
      _liveAwayName = awayName;
      _liveHomeColor = homeColor;
      _liveAwayColor = awayColor;
      _currentIndex = 3; // Passa alla tab 3 (Match)
    });
  }

  void _goToHistory() {
    setState(() => _currentIndex = 4);
    // Sveglia la schermata dello storico forzando il caricamento
    _historyKey.currentState?.reload(); 
  }

  @override
  Widget build(BuildContext context) {
    // I 4 schermi dell'applicazione (per ora segnaposto)
    final List<Widget> screens = [
      DatabaseScreen(onDataChanged: () {_squadKey.currentState?.reload(); _historyKey.currentState?.reload();}),
      SquadBuilderScreen(key: _squadKey, onSendToScoreboard: _handleSquadsToMatch),
      TeamsScreen(onLoadMatch: _handleTeamsToMatch),
      ScoreboardScreen(
        initialHomePlayers: _liveHomePlayers,
        initialAwayPlayers: _liveAwayPlayers,
        initialHomeName: _liveHomeName,
        initialAwayName: _liveAwayName,
        initialHomeColor: _liveHomeColor,
        initialAwayColor: _liveAwayColor,
        onMatchFinished: _goToHistory,
      ),
      HistoryScreen(key: _historyKey),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF334155), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF111827),
          selectedItemColor: const Color(0xFF10B981),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedFontSize: 12,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.badge_outlined),
              activeIcon: Icon(Icons.badge),
              label: 'Database',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shuffle),
              activeIcon: Icon(Icons.shuffle),
              label: 'Bilaniciatore',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups),
              label: 'Squadre',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_soccer_outlined),
              activeIcon: Icon(Icons.sports_soccer),
              label: 'Match',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard_outlined),
              activeIcon: Icon(Icons.leaderboard),
              label: 'Stats',
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: const Color(0xFF334155)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}