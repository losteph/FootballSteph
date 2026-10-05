import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/player_model.dart';
import '../services/storage_service.dart';
import '../widgets/player_fut_card.dart';

class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({super.key});

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  List<PlayerModel> _allPlayers = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _roleFilter = 'ALL';
  String _tierFilter = 'ALL';
  String _sortBy = 'ovr-desc';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final list = await StorageService.loadPlayers();
    setState(() {
      _allPlayers = list;
      _isLoading = false;
    });
  }

  Future<void> _persist() async {
    await StorageService.savePlayers(_allPlayers);
    setState(() {});
  }

  // Finestra di Dialogo per Backup e Ripristino Atleti
  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Gestione Database Atleti', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scarica o carica il file JSON del database. L\'importazione aggiungerà i nuovi atleti senza eliminare quelli attuali.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final success = await StorageService.exportPlayersToFile(_allPlayers);
                if (mounted && success) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File giocatori esportato!'), backgroundColor: Color(0xFF10B981)),
                  );
                }
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Scarica File Backup', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: const Color(0xFF042F22),
                minimumSize: const Size.fromHeight(40),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final success = await StorageService.pickAndImportPlayersMerge();
                if (success) {
                  _loadData();
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('File atleti caricato con successo!'), backgroundColor: Color(0xFF10B981)),
                    );
                  }
                }
              },
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Carica File Backup'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF334155)),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PlayerModel> get _filteredPlayers {
    var result = List<PlayerModel>.from(_allPlayers);

    if (_searchQuery.trim().isNotEmpty) {
      result = result
          .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_roleFilter != 'ALL') {
      result = result.where((p) => p.role.name == _roleFilter).toList();
    }

    if (_tierFilter != 'ALL') {
      result = result
          .where((p) => p.ovrData.tier.name.toUpperCase() == _tierFilter)
          .toList();
    }

    result.sort((a, b) {
      switch (_sortBy) {
        case 'ovr-desc':
          return b.ovrData.numeric.compareTo(a.ovrData.numeric);
        case 'ovr-asc':
          return a.ovrData.numeric.compareTo(b.ovrData.numeric);
        case 'name-asc':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'name-desc':
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        default:
          return 0;
      }
    });

    return result;
  }

  void _openPlayerModal({PlayerModel? existingPlayer}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PlayerFormModal(
        player: existingPlayer,
        onSave: (saved) {
          if (existingPlayer != null) {
            final idx = _allPlayers.indexWhere((p) => p.id == saved.id);
            if (idx != -1) _allPlayers[idx] = saved;
          } else {
            _allPlayers.add(saved);
          }
          _persist();
        },
      ),
    );
  }

  void _deletePlayer(PlayerModel player) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Conferma eliminazione', style: TextStyle(color: Colors.white)),
        content: Text('Vuoi davvero rimuovere ${player.name} dal database?',
            style: const TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              Navigator.pop(ctx);
              _allPlayers.removeWhere((p) => p.id == player.id);
              _persist();
            },
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }

    final displayList = _filteredPlayers;

    return Column(
      children: [
        // Barra comandi: ricerca, pulsante aggiungi e pulsante backup
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cerca giocatore...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                    filled: true,
                    fillColor: const Color(0xFF111827),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF10B981)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _showBackupDialog,
                icon: const Icon(Icons.cloud_sync, color: Color(0xFF94A3B8)),
                tooltip: 'Backup / Ripristino Atleti',
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () => _openPlayerModal(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Aggiungi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: const Color(0xFF042F22),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // Filtri per Ruolo
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildFilterChip('Tutti', 'ALL', _roleFilter, (v) => setState(() => _roleFilter = v)),
              _buildFilterChip('🧤 POR', 'POR', _roleFilter, (v) => setState(() => _roleFilter = v)),
              _buildFilterChip('🛡️ DIF', 'DIF', _roleFilter, (v) => setState(() => _roleFilter = v)),
              _buildFilterChip('⚙️ CEN', 'CEN', _roleFilter, (v) => setState(() => _roleFilter = v)),
              _buildFilterChip('⚡ ATT', 'ATT', _roleFilter, (v) => setState(() => _roleFilter = v)),
            ],
          ),
        ),

        // Filtri per Livello Metallo
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildFilterChip('Tutti i Livelli', 'ALL', _tierFilter, (v) => setState(() => _tierFilter = v)),
              _buildFilterChip('🏆 Oro', 'GOLD', _tierFilter, (v) => setState(() => _tierFilter = v)),
              _buildFilterChip('🥈 Argento', 'SILVER', _tierFilter, (v) => setState(() => _tierFilter = v)),
              _buildFilterChip('🥉 Bronzo', 'BRONZE', _tierFilter, (v) => setState(() => _tierFilter = v)),
            ],
          ),
        ),

        const Divider(color: Color(0xFF1E293B), height: 16),

        // Elenco giocatori o stato vuoto
        Expanded(
          child: displayList.isEmpty
              ? const Center(
                  child: Text(
                    'Nessun giocatore trovato.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: displayList.length,
                  itemBuilder: (ctx, i) {
                    final p = displayList[i];
                    return PlayerFutCard(
                      player: p,
                      onEdit: () => _openPlayerModal(existingPlayer: p),
                      onDelete: () => _deletePlayer(p),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, String activeValue, ValueChanged<String> onSelected) {
    final isSelected = activeValue == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(value),
        selectedColor: const Color(0xFF10B981),
        backgroundColor: const Color(0xFF1E293B),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF042F22) : const Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155)),
      ),
    );
  }
}

// Modal per Inserimento / Modifica Atleta
class _PlayerFormModal extends StatefulWidget {
  final PlayerModel? player;
  final ValueChanged<PlayerModel> onSave;

  const _PlayerFormModal({this.player, required this.onSave});

  @override
  State<_PlayerFormModal> createState() => _PlayerFormModalState();
}

class _PlayerFormModalState extends State<_PlayerFormModal> {
  late TextEditingController _nameController;
  late PlayerRole _selectedRole;
  late Map<String, String> _stats;

  static const List<String> _grades = ['C-', 'C', 'C+', 'B-', 'B', 'B+', 'A-', 'A', 'A+'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.player?.name ?? '');
    _selectedRole = widget.player?.role ?? PlayerRole.CEN;
    _stats = Map<String, String>.from(widget.player?.stats ?? {});
    _fillMissingStats();
  }

  void _fillMissingStats() {
    final defs = _selectedRole == PlayerRole.POR
        ? PlayerModel.porStatDefs
        : PlayerModel.fieldStatDefs;
    for (final d in defs) {
      final key = d['id']!;
      if (!_stats.containsKey(key)) {
        _stats[key] = 'B';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.player != null;
    final statDefs = _selectedRole == PlayerRole.POR
        ? PlayerModel.porStatDefs
        : PlayerModel.fieldStatDefs;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEdit ? 'Modifica Atleta' : 'Nuovo Atleta',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nome Giocatore',
                labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),

            const Text('Ruolo Principale',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),

            Row(
              children: PlayerRole.values.map((r) {
                final selected = _selectedRole == r;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selected ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFF1E293B),
                        side: BorderSide(color: selected ? const Color(0xFF10B981) : const Color(0xFF334155)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedRole = r;
                          _fillMissingStats();
                        });
                      },
                      child: Text(
                        r.name,
                        style: TextStyle(
                          color: selected ? const Color(0xFF10B981) : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            const Text('Statistiche (Voti C- / A+)',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            ...statDefs.map((def) {
              final key = def['id']!;
              final currentGrade = _stats[key] ?? 'B';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(def['label']!,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _grades.map((g) {
                            final isG = currentGrade == g;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: InkWell(
                                onTap: () => setState(() => _stats[key] = g),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isG ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isG ? const Color(0xFF10B981) : const Color(0xFF334155),
                                    ),
                                  ),
                                  child: Text(
                                    g,
                                    style: TextStyle(
                                      color: isG ? const Color(0xFF042F22) : const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Annulla', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final name = _nameController.text.trim();
                      if (name.isEmpty) return;
                      final saved = PlayerModel(
                        id: widget.player?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        role: _selectedRole,
                        stats: _stats,
                      );
                      widget.onSave(saved);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: const Color(0xFF042F22),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Salva Atleta', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}