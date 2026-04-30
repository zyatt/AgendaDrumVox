// lib/widgets/update_checker.dart

import 'package:flutter/material.dart';
import '../../utils/update_service.dart';
import 'auto_update_dialog.dart';

// ─────────────────────────────────────────
//  UpdateChecker
//
//  Envolva qualquer widget (normalmente o HomeScreen)
//  para checar atualizações automaticamente ao iniciar.
//
//  Uso em main.dart ou SplashScreen:
//
//    home: UpdateChecker(child: HomeScreen()),
//
// ─────────────────────────────────────────

class UpdateChecker extends StatefulWidget {
  final Widget child;

  const UpdateChecker({
    super.key,
    required this.child,
  });

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  @override
  void initState() {
    super.initState();
    // Aguarda o primeiro frame estar pronto antes de checar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    // Delay curto para não bloquear a renderização inicial
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final updateInfo = await UpdateService.checkForUpdates();

    if (updateInfo != null && mounted) {
      await AutoUpdateDialog.show(context, updateInfo);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}