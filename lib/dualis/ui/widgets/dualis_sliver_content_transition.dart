import 'package:flutter/material.dart';

typedef DualisSliverBuilder = Widget Function(BuildContext context);

/// Fades one sliver tree in at a time without keeping the previous table alive.
class DualisSliverContentTransition extends StatefulWidget {
  final bool showLoading;
  final Object? contentKey;
  final DualisSliverBuilder loadingBuilder;
  final DualisSliverBuilder contentBuilder;
  final Duration duration;

  const DualisSliverContentTransition({
    super.key,
    required this.showLoading,
    required this.contentKey,
    required this.loadingBuilder,
    required this.contentBuilder,
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  State<DualisSliverContentTransition> createState() =>
      _DualisSliverContentTransitionState();
}

class _DualisSliverContentTransitionState
    extends State<DualisSliverContentTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(covariant DualisSliverContentTransition oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showLoading != oldWidget.showLoading ||
        widget.contentKey != oldWidget.contentKey) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final builder = widget.showLoading
        ? widget.loadingBuilder
        : widget.contentBuilder;
    return SliverFadeTransition(
      opacity: _opacity,
      sliver: KeyedSubtree(
        key: ValueKey<Object?>(widget.contentKey),
        child: builder(context),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
