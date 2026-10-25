import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Graphique des moyennes (échelle fixe 0–100).
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.values, this.height = 170});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final summary = values.isEmpty
        ? 'Graphique des moyennes : aucune donnée'
        : 'Graphique des moyennes de ${values.length} élève(s)';
    return Semantics(
      label: summary,
      image: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _TrendPainter(values)),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values);

  final List<double> values;

  static const double _left = 30; // marge pour les repères 0/50/100

  void _label(Canvas canvas, String text, Offset offset, {Color color = AppColors.muted, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plotTop = 8.0;
    final plotBottom = size.height - 8.0;
    final plotHeight = plotBottom - plotTop;
    final plotWidth = size.width - _left - 8;
    if (plotHeight <= 0 || plotWidth <= 0) return;

    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (final mark in const [0, 50, 100]) {
      final y = plotBottom - plotHeight * mark / 100;
      canvas.drawLine(Offset(_left, y), Offset(size.width - 8, y), grid);
      _label(canvas, '$mark', Offset(0, y - 7));
    }

    if (values.isEmpty) {
      _label(canvas, 'Saisissez des notes pour afficher le graphique', Offset(_left + 8, size.height / 2 - 7));
      return;
    }

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? _left + plotWidth / 2 : _left + plotWidth * i / (values.length - 1);
      final v = values[i].clamp(0.0, 100.0).toDouble();
      points.add(Offset(x, plotBottom - plotHeight * v / 100));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final area = Path.from(path)
      ..lineTo(points.last.dx, plotBottom)
      ..lineTo(points.first.dx, plotBottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x66E51C35), Color(0x00E51C35)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(_left, plotTop, plotWidth, plotHeight)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.red
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (final p in points) {
      canvas.drawCircle(p, 3.5, Paint()..color = AppColors.redSoft);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}
