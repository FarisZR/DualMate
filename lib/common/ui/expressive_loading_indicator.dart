import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart'
    show MaterialShapeBorder, MaterialShapes;

/// A contained M3 Expressive indicator for short, indeterminate waits.
/// Uses Flutter's official Material shape morphs until material_ui provides
/// the loading indicator component. Colors come from the app's Flutter theme.
class ExpressiveLoadingIndicator extends StatefulWidget {
  const ExpressiveLoadingIndicator({super.key});

  @override
  State<ExpressiveLoadingIndicator> createState() =>
      _ExpressiveLoadingIndicatorState();
}

class _ExpressiveLoadingIndicatorState extends State<ExpressiveLoadingIndicator>
    with SingleTickerProviderStateMixin {
  // Match the seven-shape sequence used by Material's loading indicator.
  static final _shapes = [
    MaterialShapes.softBurst,
    MaterialShapes.cookie9Sided,
    MaterialShapes.pentagon,
    MaterialShapes.pill,
    MaterialShapes.sunny,
    MaterialShapes.cookie4Sided,
    MaterialShapes.oval,
  ].map((shape) => MaterialShapeBorder(shape: shape)).toList();

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4550),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
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
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: 48,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: colors.primaryContainer,
              shape: const StadiumBorder(),
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
              // Only this small shape rebuilds on ticks, never the module list.
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = _controller.value * _shapes.length;
                  final index = progress.floor() % _shapes.length;
                  return Transform.rotate(
                    angle: _controller.value * math.pi * 6,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: colors.onPrimaryContainer,
                        shape: ShapeBorder.lerp(
                          _shapes[index],
                          _shapes[(index + 1) % _shapes.length],
                          Curves.easeInOutCubicEmphasized.transform(
                            progress % 1,
                          ),
                        )!,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
