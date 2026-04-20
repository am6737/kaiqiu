// l10n_extension.dart — context.l10n 便捷访问
import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

extension L10nX on BuildContext {
  AppL10n get l10n => AppL10n.of(this);
}
