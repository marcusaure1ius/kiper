// lib/features/analytics/widgets/monthly_bar_chart.dart
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kiper/features/analytics/providers/analytics_provider.dart';
import 'package:kiper/shared/utils/format_utils.dart';

enum ChartPeriod { monthly, weekly }

class MonthlyExpenseChart extends StatefulWidget {
  final List<MonthlyTotal> data;
  final ChartPeriod period;

  const MonthlyExpenseChart({
    super.key,
    required this.data,
    this.period = ChartPeriod.monthly,
  });

  @override
  State<MonthlyExpenseChart> createState() => _MonthlyExpenseChartState();
}

class _MonthlyExpenseChartState extends State<MonthlyExpenseChart> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _initSelection();
  }

  @override
  void didUpdateWidget(covariant MonthlyExpenseChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.length != widget.data.length ||
        oldWidget.period != widget.period) {
      _initSelection();
    }
  }

  void _initSelection() {
    _selectedIndex = widget.data.length - 1;
    for (int i = widget.data.length - 1; i >= 0; i--) {
      if (!widget.data[i].isForecast) {
        _selectedIndex = i;
        break;
      }
    }
  }

  void _onInteraction(Offset local, Size size) {
    if (widget.data.length < 2) return;

    final chartW = size.width - _ChartPainter.leftPad - _ChartPainter.rightPad;
    final step = chartW / (widget.data.length - 1);
    final idx = ((local.dx - _ChartPainter.leftPad) / step)
        .round()
        .clamp(0, widget.data.length - 1);

    if (idx != _selectedIndex) {
      HapticFeedback.selectionClick();
      setState(() => _selectedIndex = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const Center(
        child: Text('Нет данных', style: TextStyle(color: Colors.white70)),
      );
    }

    final primary = Theme.of(context).colorScheme.primary;
    final hsl = HSLColor.fromColor(primary);
    final lineColor = hsl.withLightness(0.72).withSaturation(0.45).toColor();
    final accentColor = hsl.withLightness(0.68).withSaturation(0.38).toColor();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _onInteraction(d.localPosition, size),
          onHorizontalDragUpdate: (d) =>
              _onInteraction(d.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _ChartPainter(
              data: widget.data,
              selectedIndex: _selectedIndex,
              lineColor: lineColor,
              accentColor: accentColor,
              isWeekly: widget.period == ChartPeriod.weekly,
            ),
          ),
        );
      },
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<MonthlyTotal> data;
  final int selectedIndex;
  final Color lineColor;
  final Color accentColor;
  final bool isWeekly;

  static const double leftPad = 44;
  static const double rightPad = 14;
  static const double topPad = 24;
  static const double bottomPad = 42;

  _ChartPainter({
    required this.data,
    required this.selectedIndex,
    required this.lineColor,
    required this.accentColor,
    this.isWeekly = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;
    final maxVal = data.map((e) => e.amount).reduce(max) * 1.18;
    final yMax = maxVal == 0 ? 100.0 : maxVal;
    final baseY = topPad + chartH;

    final pts = List.generate(data.length, (i) {
      final x = leftPad + (i / (data.length - 1)) * chartW;
      final y = topPad + (1 - data[i].amount / yMax) * chartH;
      return Offset(x, y);
    });

    // Forecast boundary
    int fsi = data.length;
    for (int i = 0; i < data.length; i++) {
      if (data[i].isForecast) { fsi = i; break; }
    }
    final hasSplit = fsi > 0 && fsi < data.length;
    final forecastColor = lineColor.withValues(alpha: 0.45);

    final curve = _smooth(pts);
    final area = Path.from(curve)
      ..lineTo(pts.last.dx, baseY)
      ..lineTo(pts.first.dx, baseY)
      ..close();

    // 0) Y-axis labels
    _paintYLabels(canvas, yMax, chartH);

    // 1) Area gradient
    if (hasSplit) {
      final bx = pts[fsi].dx;
      _clip(canvas, Rect.fromLTRB(0, 0, bx, size.height), () {
        canvas.drawPath(area, _areaFill(baseY, lineColor, 0.28, 0.02));
      });
      _clip(canvas, Rect.fromLTRB(bx, 0, size.width + 1, size.height), () {
        canvas.drawPath(area, _areaFill(baseY, forecastColor, 0.18, 0.01));
      });
    } else {
      canvas.drawPath(area, _areaFill(baseY, lineColor, 0.28, 0.02));
    }

    // 2) Forecast dashed divider
    if (hasSplit) {
      _paintDashedLine(canvas, pts[fsi].dx, topPad, baseY);
    }

    // 3) Curve line
    if (hasSplit) {
      final bx = pts[fsi].dx;
      _clip(canvas, Rect.fromLTRB(0, 0, bx, size.height), () {
        canvas.drawPath(curve, _stroke(lineColor));
      });
      _clip(canvas, Rect.fromLTRB(bx - 1, 0, size.width + 1, size.height), () {
        canvas.drawPath(curve, _stroke(forecastColor));
      });
    } else {
      canvas.drawPath(curve, _stroke(lineColor));
    }

    // 4) Selected point indicator + tooltip
    if (selectedIndex >= 0 && selectedIndex < pts.length) {
      _paintIndicator(canvas, size, pts[selectedIndex], baseY);
    }

    // 5) X-axis labels
    _paintXLabels(canvas, size, pts);
  }

  // --- Y-axis ---

  void _paintYLabels(Canvas canvas, double yMax, double chartH) {
    final ticks = _niceYTicks(yMax);
    for (final v in ticks) {
      final y = topPad + (1 - v / yMax) * chartH;
      final tp = TextPainter(
        text: TextSpan(
          text: _fmtY(v),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 11,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, y - tp.height / 2));
    }
  }

  List<double> _niceYTicks(double maxVal) {
    if (maxVal <= 0) return [];
    final raw = maxVal / 4;
    final mag = pow(10, (log(raw) / ln10).floor()).toDouble();
    final norm = raw / mag;
    double step;
    if (norm <= 1.0) { step = mag; }
    else if (norm <= 2.0) { step = 2 * mag; }
    else if (norm <= 5.0) { step = 5 * mag; }
    else { step = 10 * mag; }

    final ticks = <double>[];
    for (double v = step; v < maxVal * 0.95; v += step) {
      ticks.add(v);
    }
    return ticks;
  }

  String _fmtY(double v) {
    if (v >= 1000000) {
      final n = v / 1000000;
      return n == n.roundToDouble() ? '${n.round()}M' : '${n.toStringAsFixed(1)}M';
    }
    if (v >= 1000) {
      final n = v / 1000;
      return n == n.roundToDouble() ? '${n.round()}K' : '${n.toStringAsFixed(1)}K';
    }
    return v.round().toString();
  }

  // --- Forecast divider ---

  void _paintDashedLine(Canvas canvas, double x, double top, double bottom) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    var y = top;
    while (y < bottom) {
      final end = min(y + dash, bottom);
      canvas.drawLine(Offset(x, y), Offset(x, end), paint);
      y += dash + gap;
    }
  }

  // --- Selected indicator (dot + tooltip) ---

  void _paintIndicator(Canvas canvas, Size size, Offset sp, double baseY) {
    final isForecast = data[selectedIndex].isForecast;
    final color = isForecast
        ? accentColor.withValues(alpha: 0.60)
        : accentColor;

    // Thin vertical line to baseline
    canvas.drawLine(
      Offset(sp.dx, sp.dy + 8),
      Offset(sp.dx, baseY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..strokeWidth = 1,
    );

    // Dot: white ring + colored center
    canvas.drawCircle(sp, 6, Paint()..color = Colors.white.withValues(alpha: 0.92));
    canvas.drawCircle(sp, 3.5, Paint()..color = color);

    // Tooltip bubble
    final amount = data[selectedIndex].amount;
    final prefix = isForecast ? '~' : '';
    final tp = TextPainter(
      text: TextSpan(
        text: '$prefix${formatAmount(amount, decimals: 0)} \u20BD',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final bw = tp.width + 16;
    final bh = tp.height + 10;

    // Above the dot; flip below if too close to top
    final showBelow = sp.dy - bh - 14 < 4;
    final by = showBelow ? sp.dy + 14 : sp.dy - bh - 14;
    var bx = (sp.dx - bw / 2).clamp(2.0, size.width - bw - 2);

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx, by, bw, bh),
      Radius.circular(bh / 2),
    );
    canvas.drawRRect(rrect, Paint()..color = color.withValues(alpha: 0.85));
    tp.paint(canvas, Offset(bx + 8, by + 5));
  }

  // --- X-axis labels ---

  void _paintXLabels(Canvas canvas, Size size, List<Offset> pts) {
    final fmt = isWeekly
        ? DateFormat('d MMM', 'ru')
        : DateFormat("MMM ''yy", 'ru');

    for (int i = 0; i < data.length; i++) {
      final sel = i == selectedIndex;
      final isForecast = data[i].isForecast;

      final Color color;
      if (sel) {
        color = Colors.white.withValues(alpha: 0.95);
      } else if (isForecast) {
        color = Colors.white.withValues(alpha: 0.32);
      } else {
        color = Colors.white.withValues(alpha: 0.55);
      }

      final tp = TextPainter(
        text: TextSpan(
          text: fmt.format(data[i].month),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(pts[i].dx, size.height - bottomPad + 12);
      canvas.rotate(-pi / 4.5);
      tp.paint(canvas, Offset(-tp.width / 2, 0));
      canvas.restore();
    }
  }

  // --- Common helpers ---

  void _clip(Canvas canvas, Rect rect, VoidCallback draw) {
    canvas.save();
    canvas.clipRect(rect);
    draw();
    canvas.restore();
  }

  Paint _areaFill(double baseY, Color color, double topA, double botA) {
    return Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, topPad),
        Offset(0, baseY),
        [color.withValues(alpha: topA), color.withValues(alpha: botA)],
      );
  }

  Paint _stroke(Color color) {
    return Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  Path _smooth(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final dx = (pts[i + 1].dx - pts[i].dx) * 0.42;
      path.cubicTo(
        pts[i].dx + dx, pts[i].dy,
        pts[i + 1].dx - dx, pts[i + 1].dy,
        pts[i + 1].dx, pts[i + 1].dy,
      );
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.selectedIndex != selectedIndex ||
      old.data.length != data.length ||
      old.lineColor != lineColor ||
      old.isWeekly != isWeekly;
}
