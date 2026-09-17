// =====================================================
// ✅ BMSChat — ЧИП ПРАВА
// =====================================================

import 'package:flutter/material.dart';

import '../themes/rasta_theme.dart';

class PermissionChip extends StatelessWidget {
    final String label;
    final bool enabled;

    const PermissionChip({
        super.key,
        required this.label,
        required this.enabled,
    });

    @override
    Widget build(BuildContext context) {
        final color = enabled ? RastaTheme.success : RastaTheme.textMuted;

        return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Icon(
                        enabled ? Icons.check_circle : Icons.cancel_outlined,
                        size: 16,
                        color: color,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                        child: Text(
                            label,
                            style: TextStyle(
                                fontSize: 13,
                                color: enabled
                                    ? RastaTheme.textPrimary
                                    : RastaTheme.textMuted,
                            ),
                        ),
                    ),
                ],
            ),
        );
    }
}