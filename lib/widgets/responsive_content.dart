import 'package:flutter/material.dart';

/// Centres page content and caps its width so the layout stays comfortable on
/// tablets, foldables and desktop windows.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 28),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Padding for a page's scroll view so its last item can scroll clear of the
/// system navigation bar and of side cutouts in landscape.
///
/// Android 15 draws every app edge-to-edge, and `SingleChildScrollView` (unlike
/// `ListView` with no explicit padding) ignores the insets. Under a `Scaffold`
/// with a bottom navigation bar the bottom inset is already consumed by it and
/// reads as zero here, so this is safe on every screen. The top is left to the
/// app bar.
EdgeInsets scrollSafePadding(BuildContext context) =>
    MediaQuery.paddingOf(context).copyWith(top: 0);
