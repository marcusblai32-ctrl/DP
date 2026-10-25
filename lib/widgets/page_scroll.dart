import 'package:flutter/material.dart';

/// Conteneur défilant commun à toutes les pages : marges adaptatives,
/// largeur maximale centrée sur grand écran et marge basse pour le bouton +.
class PageScroll extends StatelessWidget {
  const PageScroll({super.key, required this.children, this.maxWidth = 1000});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final pad = box.maxWidth < 600 ? 16.0 : 24.0;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(pad, pad, pad, 96),
            children: children,
          ),
        ),
      );
    });
  }
}
