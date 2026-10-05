import 'package:flutter/material.dart';
import '../models/player_model.dart';

class PlayerFutCard extends StatelessWidget {
  final PlayerModel player;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PlayerFutCard({
    super.key,
    required this.player,
    required this.onEdit,
    required this.onDelete,
  });

  // Gradienti di sfondo stile card FUT
  LinearGradient _getCardGradient(CardTier tier) {
    switch (tier) {
      case CardTier.gold:
        return const LinearGradient(
          colors: [Color(0xFF453205), Color(0xFF1C1400)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardTier.silver:
        return const LinearGradient(
          colors: [Color(0xFF334155), Color(0xFF172033)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case CardTier.bronze:
        return const LinearGradient(
          colors: [Color(0xFF451A03), Color(0xFF1A0A02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  // Colore del bordo coordinato
  Color _getBorderColor(CardTier tier) {
    switch (tier) {
      case CardTier.gold:
        return const Color(0xFFF59E0B);
      case CardTier.silver:
        return const Color(0xFF94A3B8);
      case CardTier.bronze:
        return const Color(0xFFB45309);
    }
  }

  // Colore del testo dell'OVR
  Color _getOvrTextColor(CardTier tier) {
    switch (tier) {
      case CardTier.gold:
        return const Color(0xFFFBBF24);
      case CardTier.silver:
        return const Color(0xFFE2E8F0);
      case CardTier.bronze:
        return const Color(0xFFF97316);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ovr = player.ovrData;
    final statDefs = player.role == PlayerRole.POR
        ? PlayerModel.porStatDefs
        : PlayerModel.fieldStatDefs;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: _getCardGradient(ovr.tier),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getBorderColor(ovr.tier), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _getBorderColor(ovr.tier).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Intestazione Card: OVR Box + Nome + Ruolo
          Row(
            children: [
              // Box OVR
              Container(
                width: 48,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ovr.letter,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _getOvrTextColor(ovr.tier),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ovr.numeric}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Nome e Badge Ruolo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: player.roleColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: player.roleColor, width: 1),
                      ),
                      child: Text(
                        player.role.name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: player.roleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Griglia Statistiche
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: statDefs.map((def) {
                final key = def['id']!;
                final label = def['label']!;
                final val = player.stats[key] ?? 'B';
                return Column(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      val,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Pulsanti Azioni
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 14, color: Color(0xFF94A3B8)),
                label: const Text(
                  'Modifica',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
                label: const Text(
                  'Elimina',
                  style: TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}