import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An animated gradient mesh background for glassmorphism effect.
class GradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final bool animate;
  final Duration animationDuration;
  final GradientStyle style;

  const GradientBackground({
    super.key,
    required this.child,
    this.colors,
    this.animate = true,
    this.animationDuration = const Duration(seconds: 10),
    this.style = GradientStyle.mesh,
  });

  @override
  State<GradientBackground> createState() => _GradientBackgroundState();
}

class _GradientBackgroundState extends State<GradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultColors = isDark
        ? [
            const Color(0xFF0A0A0A),
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E),
            const Color(0xFF0F0F23),
          ]
        : [
            const Color(0xFFF8F9FF),
            const Color(0xFFE8EEFF),
            const Color(0xFFF0E6FF),
            const Color(0xFFFFE6F0),
          ];

    final colors = widget.colors ?? defaultColors;

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: switch (widget.style) {
                  GradientStyle.mesh => _MeshGradientPainter(
                      colors: colors,
                      animation: _controller.value,
                    ),
                  GradientStyle.orbs => _OrbGradientPainter(
                      colors: colors,
                      animation: _controller.value,
                    ),
                  GradientStyle.waves => _WaveGradientPainter(
                      colors: colors,
                      animation: _controller.value,
                    ),
                  GradientStyle.simple => _SimpleGradientPainter(
                      colors: colors,
                      animation: _controller.value,
                    ),
                },
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

enum GradientStyle {
  mesh,
  orbs,
  waves,
  simple,
}

class _MeshGradientPainter extends CustomPainter {
  final List<Color> colors;
  final double animation;

  _MeshGradientPainter({
    required this.colors,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base gradient
    final baseGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
    canvas.drawRect(rect, Paint()..shader = baseGradient.createShader(rect));

    // Animated orbs for mesh effect
    final orbCount = 4;
    for (var i = 0; i < orbCount; i++) {
      final phase = (animation + i / orbCount) % 1.0;
      final x = size.width *
          (0.2 + 0.6 * math.sin(phase * math.pi * 2 + i * math.pi / 2));
      final y = size.height *
          (0.2 + 0.6 * math.cos(phase * math.pi * 2 + i * math.pi / 3));
      final radius = size.width * (0.3 + 0.1 * math.sin(phase * math.pi * 4));

      final orbGradient = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          colors[i % colors.length].withValues(alpha: 0.4),
          colors[i % colors.length].withValues(alpha: 0.0),
        ],
      );

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..shader = orbGradient.createShader(
            Rect.fromCircle(center: Offset(x, y), radius: radius),
          )
          ..blendMode = BlendMode.softLight,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MeshGradientPainter oldDelegate) {
    return animation != oldDelegate.animation;
  }
}

class _OrbGradientPainter extends CustomPainter {
  final List<Color> colors;
  final double animation;

  _OrbGradientPainter({
    required this.colors,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Dark base
    canvas.drawRect(
      rect,
      Paint()..color = colors.first,
    );

    // Floating orbs
    final orbPositions = [
      Offset(0.2, 0.3),
      Offset(0.8, 0.2),
      Offset(0.5, 0.7),
      Offset(0.9, 0.8),
    ];

    for (var i = 0; i < orbPositions.length; i++) {
      final basePos = orbPositions[i];
      final phase = (animation + i * 0.25) % 1.0;
      final offsetX = 0.1 * math.sin(phase * math.pi * 2);
      final offsetY = 0.1 * math.cos(phase * math.pi * 2);

      final x = size.width * (basePos.dx + offsetX);
      final y = size.height * (basePos.dy + offsetY);
      final radius = size.width * 0.4;

      final orbGradient = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          colors[(i + 1) % colors.length].withValues(alpha: 0.6),
          colors[(i + 1) % colors.length].withValues(alpha: 0.0),
        ],
      );

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..shader = orbGradient.createShader(
            Rect.fromCircle(center: Offset(x, y), radius: radius),
          )
          ..blendMode = BlendMode.screen,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbGradientPainter oldDelegate) {
    return animation != oldDelegate.animation;
  }
}

class _WaveGradientPainter extends CustomPainter {
  final List<Color> colors;
  final double animation;

  _WaveGradientPainter({
    required this.colors,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base gradient
    final baseGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [colors.first, colors.last],
    );
    canvas.drawRect(rect, Paint()..shader = baseGradient.createShader(rect));

    // Animated waves
    for (var w = 0; w < 3; w++) {
      final path = Path();
      final waveHeight = size.height * 0.1;
      final baseY = size.height * (0.3 + w * 0.2);
      final phase = animation * math.pi * 2 + w * math.pi / 3;

      path.moveTo(0, baseY);

      for (var x = 0.0; x <= size.width; x += 10) {
        final y = baseY +
            math.sin((x / size.width) * math.pi * 4 + phase) * waveHeight;
        path.lineTo(x, y);
      }

      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();

      final waveGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors[(w + 1) % colors.length].withValues(alpha: 0.3),
          colors[(w + 2) % colors.length].withValues(alpha: 0.1),
        ],
      );

      canvas.drawPath(
        path,
        Paint()
          ..shader = waveGradient.createShader(rect)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveGradientPainter oldDelegate) {
    return animation != oldDelegate.animation;
  }
}

class _SimpleGradientPainter extends CustomPainter {
  final List<Color> colors;
  final double animation;

  _SimpleGradientPainter({
    required this.colors,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Rotating gradient
    final angle = animation * math.pi * 2;
    final gradient = LinearGradient(
      begin: Alignment(math.cos(angle), math.sin(angle)),
      end: Alignment(-math.cos(angle), -math.sin(angle)),
      colors: colors,
    );

    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant _SimpleGradientPainter oldDelegate) {
    return animation != oldDelegate.animation;
  }
}

/// A scaffold with gradient background built-in.
class GradientScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final List<Color>? gradientColors;
  final bool animateGradient;
  final GradientStyle gradientStyle;
  final bool extendBodyBehindAppBar;
  final bool extendBody;

  const GradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.gradientColors,
    this.animateGradient = true,
    this.gradientStyle = GradientStyle.mesh,
    this.extendBodyBehindAppBar = true,
    this.extendBody = true,
  });

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      colors: gradientColors,
      animate: animateGradient,
      style: gradientStyle,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        extendBody: extendBody,
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}
