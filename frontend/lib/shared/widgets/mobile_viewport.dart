import 'package:flutter/material.dart';

class MobileViewport extends StatelessWidget {
  const MobileViewport({required this.child, super.key});

  static const double maxPhoneWidth = 480;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxPhoneWidth),
          child: child,
        ),
      ),
    );
  }
}
