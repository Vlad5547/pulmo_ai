import '../models/analysis_result.dart';
import 'generated/app_localizations.dart';

/// Localised wording for a verdict.
///
/// Kept next to the localisations rather than on the enum so the model layer
/// stays free of UI copy and the same verdict reads correctly in every
/// supported language.
extension PneumoniaVerdictL10n on PneumoniaVerdict {
  String label(AppL10n l10n) => switch (this) {
        PneumoniaVerdict.pneumonia => l10n.verdictPneumonia,
        PneumoniaVerdict.normal => l10n.verdictNormal,
      };

  String description(AppL10n l10n) => switch (this) {
        PneumoniaVerdict.pneumonia => l10n.verdictPneumoniaDescription,
        PneumoniaVerdict.normal => l10n.verdictNormalDescription,
      };
}
