import 'package:flutter/material.dart';

/// Semantic colours for clinical states — kept out of [ColorScheme] so the
/// meaning ("finding" vs "clear") is explicit at every call site.
@immutable
class ClinicalColors extends ThemeExtension<ClinicalColors> {
  const ClinicalColors({
    required this.finding,
    required this.findingContainer,
    required this.onFindingContainer,
    required this.clear,
    required this.clearContainer,
    required this.onClearContainer,
    required this.scanBackdrop,
  });

  final Color finding;
  final Color findingContainer;
  final Color onFindingContainer;
  final Color clear;
  final Color clearContainer;
  final Color onClearContainer;

  /// Backdrop behind an X-ray, always dark so the scan keeps its contrast.
  final Color scanBackdrop;

  static const light = ClinicalColors(
    finding: Color(0xFFC8322B),
    findingContainer: Color(0xFFFDECEA),
    onFindingContainer: Color(0xFF7A1710),
    clear: Color(0xFF1B7F5B),
    clearContainer: Color(0xFFE6F5EE),
    onClearContainer: Color(0xFF0D4A34),
    scanBackdrop: Color(0xFF0C1116),
  );

  static const dark = ClinicalColors(
    finding: Color(0xFFFF8A80),
    findingContainer: Color(0xFF3B1512),
    onFindingContainer: Color(0xFFFFD9D4),
    clear: Color(0xFF6FD8A8),
    clearContainer: Color(0xFF0E2A20),
    onClearContainer: Color(0xFFC7F0DC),
    scanBackdrop: Color(0xFF05080B),
  );

  @override
  ClinicalColors copyWith({
    Color? finding,
    Color? findingContainer,
    Color? onFindingContainer,
    Color? clear,
    Color? clearContainer,
    Color? onClearContainer,
    Color? scanBackdrop,
  }) {
    return ClinicalColors(
      finding: finding ?? this.finding,
      findingContainer: findingContainer ?? this.findingContainer,
      onFindingContainer: onFindingContainer ?? this.onFindingContainer,
      clear: clear ?? this.clear,
      clearContainer: clearContainer ?? this.clearContainer,
      onClearContainer: onClearContainer ?? this.onClearContainer,
      scanBackdrop: scanBackdrop ?? this.scanBackdrop,
    );
  }

  @override
  ClinicalColors lerp(ThemeExtension<ClinicalColors>? other, double t) {
    if (other is! ClinicalColors) return this;
    return ClinicalColors(
      finding: Color.lerp(finding, other.finding, t)!,
      findingContainer:
          Color.lerp(findingContainer, other.findingContainer, t)!,
      onFindingContainer:
          Color.lerp(onFindingContainer, other.onFindingContainer, t)!,
      clear: Color.lerp(clear, other.clear, t)!,
      clearContainer: Color.lerp(clearContainer, other.clearContainer, t)!,
      onClearContainer:
          Color.lerp(onClearContainer, other.onClearContainer, t)!,
      scanBackdrop: Color.lerp(scanBackdrop, other.scanBackdrop, t)!,
    );
  }
}

extension ClinicalTheme on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
  ClinicalColors get clinical => Theme.of(this).extension<ClinicalColors>()!;
}

abstract final class AppTheme {
  static const _seed = Color(0xFF0E7C86);

  static ThemeData light() => _build(Brightness.light, ClinicalColors.light);

  static ThemeData dark() => _build(Brightness.dark, ClinicalColors.dark);

  static ThemeData _build(Brightness brightness, ClinicalColors clinical) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final isLight = brightness == Brightness.light;
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: isLight
          ? const Color(0xFFF6F8FA)
          : const Color(0xFF0F1418),
      extensions: [clinical],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0.5,
        backgroundColor: isLight
            ? const Color(0xFFF6F8FA)
            : const Color(0xFF0F1418),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isLight ? Colors.white : const Color(0xFF171E24),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isLight ? 0.6 : 0.4),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: isLight ? Colors.white : const Color(0xFF141A20),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: base.textTheme.apply(fontFamily: null),
    );
  }
}
