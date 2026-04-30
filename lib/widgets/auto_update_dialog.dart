// lib/widgets/auto_update_dialog.dart

import 'package:flutter/material.dart';
import '../../utils/update_service.dart';
import '../../utils/app_theme.dart';

// ─────────────────────────────────────────
//  Dialog de atualização automática
//  Adaptado para Android (instalação via sistema)
// ─────────────────────────────────────────

class AutoUpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const AutoUpdateDialog({super.key, required this.updateInfo});

  /// Abre o dialog; resolve quando o usuário fecha ou a instalação é iniciada.
  static Future<void> show(BuildContext context, UpdateInfo updateInfo) {
    return showDialog(
      context: context,
      barrierDismissible: !updateInfo.mandatory,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => AutoUpdateDialog(updateInfo: updateInfo),
    );
  }

  @override
  State<AutoUpdateDialog> createState() => _AutoUpdateDialogState();
}

class _AutoUpdateDialogState extends State<AutoUpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _startUpdate() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });

    final error = await UpdateService.downloadAndInstallUpdate(
      widget.updateInfo.downloadUrl,
      (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (mounted) {
      if (error != null) {
        setState(() {
          _downloading = false;
          _error = error;
        });
      } else {
        // Download concluído e instalador aberto com sucesso.
        // Fecha o dialog para o usuário ver a tela de instalação do Android.
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;
    final hasNotes = info.releaseNotes.isNotEmpty;

    return Dialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cabeçalho ──────────────────────────────
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nova versão disponível',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            _VersionBadge(
                              label: 'v${info.currentVersion}',
                              color: AppTheme.textMuted,
                              bg: AppTheme.surfaceVariant,
                            ),
                            const Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 12,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            _VersionBadge(
                              label: 'v${info.latestVersion}',
                              color: AppTheme.primary,
                              bg: AppTheme.primary.withValues(alpha: 0.12),
                              border: AppTheme.primary.withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!info.mandatory && !_downloading)
                    _IconClose(onTap: () => Navigator.pop(context)),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 20),

              // ── Notas de versão ─────────────────────────
              if (hasNotes) ...[
                const Text(
                  'O QUE HÁ DE NOVO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 130),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      info.releaseNotes,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Progresso de download ───────────────────
              if (_downloading) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _progress < 1.0
                          ? 'Baixando atualização...'
                          : 'Abrindo instalador...',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${(_progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 7,
                    backgroundColor: AppTheme.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 10),
                // Texto específico para Android: o sistema pergunta ao usuário
                const Text(
                  'O instalador do Android será aberto em seguida.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
              ],

              // ── Mensagem de erro ────────────────────────
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppTheme.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.error,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Botões de ação ──────────────────────────
              if (!_downloading) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!info.mandatory) ...[
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                        ),
                        child: const Text('Agora não'),
                      ),
                      const SizedBox(width: 10),
                    ],
                    ElevatedButton.icon(
                      onPressed: _startUpdate,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        _error != null ? 'Tentar novamente' : 'Atualizar agora',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: const Color(0xFF1A1000),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Widgets auxiliares internos
// ─────────────────────────────────────────

class _VersionBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final Color? border;

  const _VersionBadge({
    required this.label,
    required this.color,
    required this.bg,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: border ?? AppTheme.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _IconClose extends StatelessWidget {
  final VoidCallback onTap;

  const _IconClose({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Icon(
          Icons.close_rounded,
          size: 16,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}