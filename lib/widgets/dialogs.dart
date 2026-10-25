import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Corps de dialogue défilant, borné en largeur : évite les débordements
/// sur petit écran et quand le clavier est affiché.
class DialogBody extends StatelessWidget {
  const DialogBody({super.key, required this.child, this.maxWidth = 460});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: maxWidth,
      child: SingleChildScrollView(child: child),
    );
  }
}

/// Hauteur raisonnable pour une liste dans un dialogue.
double dialogListHeight(BuildContext context) {
  final h = MediaQuery.sizeOf(context).height;
  return math.min(460.0, math.max(180.0, h * 0.5));
}

/// Message d'erreur de formulaire affiché dans un dialogue.
class FormErrorText extends StatelessWidget {
  const FormErrorText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message!, style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

/// Dialogue de confirmation standard.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.black)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}
