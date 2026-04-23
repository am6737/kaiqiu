// l10n_extension.dart — context.l10n 便捷访问
import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

extension L10nX on BuildContext {
  AppL10n get l10n => AppL10n.of(this);
}

extension PositionL10n on AppL10n {
  String positionName(String code) => switch (code) {
        'GK' => position_gk,
        'CB' => position_cb,
        'LCB' => position_lcb,
        'RCB' => position_rcb,
        'LB' => position_lb,
        'RB' => position_rb,
        'CM' => position_cm,
        'LCM' => position_lcm,
        'RCM' => position_rcm,
        'LW' => position_lw,
        'RW' => position_rw,
        'ST' => position_st,
        'LM' => position_lm,
        'RM' => position_rm,
        'LWB' => position_lwb,
        'RWB' => position_rwb,
        'LS' => position_ls,
        'RS' => position_rs,
        'CAM' => position_cam,
        'CDM' => position_cdm,
        'CF' => position_cf,
        _ => code,
      };
}
