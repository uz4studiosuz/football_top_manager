import 'package:flutter/material.dart';
import 'player.dart';
import 'crest.dart';
import '../l10n/l10n.dart';

export 'crest.dart';

/// Murabbiy Uslublari (Team Playstyle)
enum TeamPlaystyle {
  outWide(
    'Out Wide',
    'Qanotlarni keng ochish, kross va jarima maydoniga yugurish.',
    Icons.open_in_full,
    Color(0xFF374DF5),
  ),
  longBallCounter(
    'Long Ball Counter',
    'Past blok va tez uzun uzatma.',
    Icons.north_east,
    Color(0xFF374DF5),
  ),
  possession(
    'Possession Game',
    'Qisqa paslar, uchburchaklar va maydon nazorati.',
    Icons.grain_rounded,
    Color(0xFF374DF5),
  ),
  quickCounter(
    'Quick Counter',
    'To‘p olingach bo‘sh hududga chaqqon qarshi hujum.',
    Icons.bolt_rounded,
    Color(0xFF374DF5),
  ),
  highPressing(
    'High Pressing',
    'Gegenpress – raqib yarmida to‘pni qaytarib olish.',
    Icons.local_fire_department_rounded,
    Color(0xFF374DF5),
  ),
  longBall(
    'Long Ball / Park Bus',
    'Mustahkam himoya va uzun paslar bilan qarshi hujum.',
    Icons.shield_rounded,
    Color(0xFF374DF5),
  ),
  overload(
    'Overload',
    'Bir tomonda son ustunligi yaratib, keskin pas bilan ochiq tomonga o‘tish.',
    Icons.compare_arrows_rounded,
    Color(0xFF374DF5),
  );

  const TeamPlaystyle(
    this.displayName,
    this._description,
    this.icon,
    this.accentColor,
  );
  final String displayName;
  final String _description;
  String get description => tr(_description);
  final IconData icon;
  final Color accentColor;
}

/// Taktik slot (11 ta o'yinchi joylashuvi maydonda)
class TacticalSlot {
  final int index;
  final PlayerPosition defaultPosition;
  final double x; // 0.0 chap qanot – 1.0 o'ng qanot
  final double y; // 0.0 raqib darvozasi – 1.0 o'z darvozamiz
  final String roleLabel;
  const TacticalSlot({
    required this.index,
    required this.defaultPosition,
    required this.x,
    required this.y,
    required this.roleLabel,
  });
}

typedef _S = TacticalSlot;
const _gk = _S(
  index: 0,
  defaultPosition: PlayerPosition.gk,
  x: 0.5,
  y: 0.91,
  roleLabel: 'GK',
);

/// Taktik sxemalar (Formations)
enum FormationType {
  f433('4-3-3 Attack'),
  f4231('4-2-3-1 Balanced'),
  f442('4-4-2 Classic'),
  f352('3-5-2 Midfield Heavy'),
  f532('5-3-2 Defensive'),
  f4141('4-1-4-1 Control'),
  f343('3-4-3 Wide Attack'),
  f41212('4-1-2-1-2 Diamond'),
  f433d('4-3-3 Holding'),
  f4222('4-2-2-2 Box'),
  f4411('4-4-1-1 Classic'),
  f451('4-5-1 Compact'),
  f3412('3-4-1-2 Twin Strikers'),
  f3421('3-4-2-1 Christmas Tree'),
  f541('5-4-1 Low Block'),
  f4321('4-3-2-1 Narrow');

  const FormationType(this._label);
  final String _label;
  String get label => tr(_label);
  String get short => label.split(' ').first;

  List<TacticalSlot> get slots => switch (this) {
    FormationType.f433 => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.lb, x: 0.14, y: 0.72, roleLabel: 'LB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.38, y: 0.76, roleLabel: 'CB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.62, y: 0.76, roleLabel: 'CB'),
      _S(index: 4, defaultPosition: PlayerPosition.rb, x: 0.86, y: 0.72, roleLabel: 'RB'),
      _S(index: 5, defaultPosition: PlayerPosition.dmf, x: 0.50, y: 0.59, roleLabel: 'DMF'),
      _S(index: 6, defaultPosition: PlayerPosition.cmf, x: 0.30, y: 0.47, roleLabel: 'LCMF'),
      _S(index: 7, defaultPosition: PlayerPosition.amf, x: 0.70, y: 0.45, roleLabel: 'RAMF'),
      _S(index: 8, defaultPosition: PlayerPosition.lwf, x: 0.17, y: 0.23, roleLabel: 'LWF'),
      _S(index: 9, defaultPosition: PlayerPosition.cf, x: 0.50, y: 0.16, roleLabel: 'CF'),
      _S(index: 10, defaultPosition: PlayerPosition.rwf, x: 0.83, y: 0.23, roleLabel: 'RWF'),
    ],
    FormationType.f4231 => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.lb, x: 0.14, y: 0.72, roleLabel: 'LB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.38, y: 0.76, roleLabel: 'CB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.62, y: 0.76, roleLabel: 'CB'),
      _S(index: 4, defaultPosition: PlayerPosition.rb, x: 0.86, y: 0.72, roleLabel: 'RB'),
      _S(index: 5, defaultPosition: PlayerPosition.dmf, x: 0.36, y: 0.58, roleLabel: 'LDMF'),
      _S(index: 6, defaultPosition: PlayerPosition.dmf, x: 0.64, y: 0.58, roleLabel: 'RDMF'),
      _S(index: 7, defaultPosition: PlayerPosition.lmf, x: 0.18, y: 0.36, roleLabel: 'LAMF'),
      _S(index: 8, defaultPosition: PlayerPosition.amf, x: 0.50, y: 0.36, roleLabel: 'CAMF'),
      _S(index: 9, defaultPosition: PlayerPosition.rmf, x: 0.82, y: 0.36, roleLabel: 'RAMF'),
      _S(index: 10, defaultPosition: PlayerPosition.cf, x: 0.50, y: 0.16, roleLabel: 'CF'),
    ],
    FormationType.f442 => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.lb, x: 0.14, y: 0.72, roleLabel: 'LB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.38, y: 0.76, roleLabel: 'CB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.62, y: 0.76, roleLabel: 'CB'),
      _S(index: 4, defaultPosition: PlayerPosition.rb, x: 0.86, y: 0.72, roleLabel: 'RB'),
      _S(index: 5, defaultPosition: PlayerPosition.lmf, x: 0.15, y: 0.47, roleLabel: 'LMF'),
      _S(index: 6, defaultPosition: PlayerPosition.cmf, x: 0.38, y: 0.51, roleLabel: 'LCMF'),
      _S(index: 7, defaultPosition: PlayerPosition.cmf, x: 0.62, y: 0.51, roleLabel: 'RCMF'),
      _S(index: 8, defaultPosition: PlayerPosition.rmf, x: 0.85, y: 0.47, roleLabel: 'RMF'),
      _S(index: 9, defaultPosition: PlayerPosition.cf, x: 0.37, y: 0.19, roleLabel: 'LCF'),
      _S(index: 10, defaultPosition: PlayerPosition.cf, x: 0.63, y: 0.19, roleLabel: 'RCF'),
    ],
    FormationType.f352 => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.cb, x: 0.26, y: 0.75, roleLabel: 'LCB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.50, y: 0.78, roleLabel: 'CB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.74, y: 0.75, roleLabel: 'RCB'),
      _S(index: 4, defaultPosition: PlayerPosition.lmf, x: 0.11, y: 0.48, roleLabel: 'LWB'),
      _S(index: 5, defaultPosition: PlayerPosition.dmf, x: 0.38, y: 0.58, roleLabel: 'LDMF'),
      _S(index: 6, defaultPosition: PlayerPosition.cmf, x: 0.62, y: 0.55, roleLabel: 'RCMF'),
      _S(index: 7, defaultPosition: PlayerPosition.rmf, x: 0.89, y: 0.48, roleLabel: 'RWB'),
      _S(index: 8, defaultPosition: PlayerPosition.amf, x: 0.50, y: 0.37, roleLabel: 'AMF'),
      _S(index: 9, defaultPosition: PlayerPosition.cf, x: 0.37, y: 0.18, roleLabel: 'LCF'),
      _S(index: 10, defaultPosition: PlayerPosition.cf, x: 0.63, y: 0.18, roleLabel: 'RCF'),
    ],
    FormationType.f532 => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.lb, x: 0.11, y: 0.69, roleLabel: 'LWB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.30, y: 0.77, roleLabel: 'LCB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.50, y: 0.79, roleLabel: 'CCB'),
      _S(index: 4, defaultPosition: PlayerPosition.cb, x: 0.70, y: 0.77, roleLabel: 'RCB'),
      _S(index: 5, defaultPosition: PlayerPosition.rb, x: 0.89, y: 0.69, roleLabel: 'RWB'),
      _S(index: 6, defaultPosition: PlayerPosition.cmf, x: 0.30, y: 0.50, roleLabel: 'LCMF'),
      _S(index: 7, defaultPosition: PlayerPosition.dmf, x: 0.50, y: 0.56, roleLabel: 'DMF'),
      _S(index: 8, defaultPosition: PlayerPosition.cmf, x: 0.70, y: 0.50, roleLabel: 'RCMF'),
      _S(index: 9, defaultPosition: PlayerPosition.cf, x: 0.38, y: 0.20, roleLabel: 'LCF'),
      _S(index: 10, defaultPosition: PlayerPosition.cf, x: 0.62, y: 0.20, roleLabel: 'RCF'),
    ],
    FormationType.f4141 => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.lb, x: 0.14, y: 0.72, roleLabel: 'LB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.38, y: 0.76, roleLabel: 'CB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.62, y: 0.76, roleLabel: 'CB'),
      _S(index: 4, defaultPosition: PlayerPosition.rb, x: 0.86, y: 0.72, roleLabel: 'RB'),
      _S(index: 5, defaultPosition: PlayerPosition.dmf, x: 0.50, y: 0.60, roleLabel: 'DMF'),
      _S(index: 6, defaultPosition: PlayerPosition.lmf, x: 0.15, y: 0.42, roleLabel: 'LMF'),
      _S(index: 7, defaultPosition: PlayerPosition.cmf, x: 0.38, y: 0.44, roleLabel: 'LCMF'),
      _S(index: 8, defaultPosition: PlayerPosition.cmf, x: 0.62, y: 0.44, roleLabel: 'RCMF'),
      _S(index: 9, defaultPosition: PlayerPosition.rmf, x: 0.85, y: 0.42, roleLabel: 'RMF'),
      _S(index: 10, defaultPosition: PlayerPosition.cf, x: 0.50, y: 0.17, roleLabel: 'CF'),
    ],
    FormationType.f343 => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.cb, x: 0.26, y: 0.75, roleLabel: 'LCB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.50, y: 0.78, roleLabel: 'CB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.74, y: 0.75, roleLabel: 'RCB'),
      _S(index: 4, defaultPosition: PlayerPosition.lmf, x: 0.12, y: 0.50, roleLabel: 'LWB'),
      _S(index: 5, defaultPosition: PlayerPosition.cmf, x: 0.38, y: 0.54, roleLabel: 'LCMF'),
      _S(index: 6, defaultPosition: PlayerPosition.cmf, x: 0.62, y: 0.54, roleLabel: 'RCMF'),
      _S(index: 7, defaultPosition: PlayerPosition.rmf, x: 0.88, y: 0.50, roleLabel: 'RWB'),
      _S(index: 8, defaultPosition: PlayerPosition.lwf, x: 0.20, y: 0.23, roleLabel: 'LWF'),
      _S(index: 9, defaultPosition: PlayerPosition.cf, x: 0.50, y: 0.16, roleLabel: 'CF'),
      _S(index: 10, defaultPosition: PlayerPosition.rwf, x: 0.80, y: 0.23, roleLabel: 'RWF'),
    ],
    FormationType.f41212 => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.lb, x: 0.14, y: 0.72, roleLabel: 'LB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.38, y: 0.76, roleLabel: 'CB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.62, y: 0.76, roleLabel: 'CB'),
      _S(index: 4, defaultPosition: PlayerPosition.rb, x: 0.86, y: 0.72, roleLabel: 'RB'),
      _S(index: 5, defaultPosition: PlayerPosition.dmf, x: 0.50, y: 0.61, roleLabel: 'DMF'),
      _S(index: 6, defaultPosition: PlayerPosition.cmf, x: 0.30, y: 0.49, roleLabel: 'LCMF'),
      _S(index: 7, defaultPosition: PlayerPosition.cmf, x: 0.70, y: 0.49, roleLabel: 'RCMF'),
      _S(index: 8, defaultPosition: PlayerPosition.amf, x: 0.50, y: 0.36, roleLabel: 'AMF'),
      _S(index: 9, defaultPosition: PlayerPosition.cf, x: 0.38, y: 0.18, roleLabel: 'LCF'),
      _S(index: 10, defaultPosition: PlayerPosition.cf, x: 0.62, y: 0.18, roleLabel: 'RCF'),
    ],
    FormationType.f433d => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.lb, x: 0.14, y: 0.72, roleLabel: 'LB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.38, y: 0.76, roleLabel: 'CB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.62, y: 0.76, roleLabel: 'CB'),
      _S(index: 4, defaultPosition: PlayerPosition.rb, x: 0.86, y: 0.72, roleLabel: 'RB'),
      _S(index: 5, defaultPosition: PlayerPosition.dmf, x: 0.50, y: 0.60, roleLabel: 'DMF'),
      _S(index: 6, defaultPosition: PlayerPosition.cmf, x: 0.32, y: 0.50, roleLabel: 'LCMF'),
      _S(index: 7, defaultPosition: PlayerPosition.cmf, x: 0.68, y: 0.50, roleLabel: 'RCMF'),
      _S(index: 8, defaultPosition: PlayerPosition.lwf, x: 0.17, y: 0.24, roleLabel: 'LWF'),
      _S(index: 9, defaultPosition: PlayerPosition.cf, x: 0.50, y: 0.16, roleLabel: 'CF'),
      _S(index: 10, defaultPosition: PlayerPosition.rwf, x: 0.83, y: 0.24, roleLabel: 'RWF'),
    ],
    FormationType.f4222 => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.lb, x: 0.14, y: 0.72, roleLabel: 'LB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.38, y: 0.76, roleLabel: 'CB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.62, y: 0.76, roleLabel: 'CB'),
      _S(index: 4, defaultPosition: PlayerPosition.rb, x: 0.86, y: 0.72, roleLabel: 'RB'),
      _S(index: 5, defaultPosition: PlayerPosition.dmf, x: 0.36, y: 0.58, roleLabel: 'LDMF'),
      _S(index: 6, defaultPosition: PlayerPosition.dmf, x: 0.64, y: 0.58, roleLabel: 'RDMF'),
      _S(index: 7, defaultPosition: PlayerPosition.amf, x: 0.24, y: 0.38, roleLabel: 'LAMF'),
      _S(index: 8, defaultPosition: PlayerPosition.amf, x: 0.76, y: 0.38, roleLabel: 'RAMF'),
      _S(index: 9, defaultPosition: PlayerPosition.cf, x: 0.38, y: 0.18, roleLabel: 'LCF'),
      _S(index: 10, defaultPosition: PlayerPosition.cf, x: 0.62, y: 0.18, roleLabel: 'RCF'),
    ],
    FormationType.f4411 => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.lb, x: 0.14, y: 0.72, roleLabel: 'LB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.38, y: 0.76, roleLabel: 'CB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.62, y: 0.76, roleLabel: 'CB'),
      _S(index: 4, defaultPosition: PlayerPosition.rb, x: 0.86, y: 0.72, roleLabel: 'RB'),
      _S(index: 5, defaultPosition: PlayerPosition.lmf, x: 0.15, y: 0.47, roleLabel: 'LMF'),
      _S(index: 6, defaultPosition: PlayerPosition.cmf, x: 0.38, y: 0.52, roleLabel: 'LCMF'),
      _S(index: 7, defaultPosition: PlayerPosition.cmf, x: 0.62, y: 0.52, roleLabel: 'RCMF'),
      _S(index: 8, defaultPosition: PlayerPosition.rmf, x: 0.85, y: 0.47, roleLabel: 'RMF'),
      _S(index: 9, defaultPosition: PlayerPosition.ss, x: 0.50, y: 0.30, roleLabel: 'SS'),
      _S(index: 10, defaultPosition: PlayerPosition.cf, x: 0.50, y: 0.16, roleLabel: 'CF'),
    ],
    FormationType.f451 => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.lb, x: 0.14, y: 0.72, roleLabel: 'LB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.38, y: 0.76, roleLabel: 'CB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.62, y: 0.76, roleLabel: 'CB'),
      _S(index: 4, defaultPosition: PlayerPosition.rb, x: 0.86, y: 0.72, roleLabel: 'RB'),
      _S(index: 5, defaultPosition: PlayerPosition.lmf, x: 0.13, y: 0.44, roleLabel: 'LMF'),
      _S(index: 6, defaultPosition: PlayerPosition.cmf, x: 0.33, y: 0.48, roleLabel: 'LCMF'),
      _S(index: 7, defaultPosition: PlayerPosition.dmf, x: 0.50, y: 0.56, roleLabel: 'DMF'),
      _S(index: 8, defaultPosition: PlayerPosition.cmf, x: 0.67, y: 0.48, roleLabel: 'RCMF'),
      _S(index: 9, defaultPosition: PlayerPosition.rmf, x: 0.87, y: 0.44, roleLabel: 'RMF'),
      _S(index: 10, defaultPosition: PlayerPosition.cf, x: 0.50, y: 0.18, roleLabel: 'CF'),
    ],
    FormationType.f3412 => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.cb, x: 0.26, y: 0.75, roleLabel: 'LCB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.50, y: 0.78, roleLabel: 'CB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.74, y: 0.75, roleLabel: 'RCB'),
      _S(index: 4, defaultPosition: PlayerPosition.lmf, x: 0.12, y: 0.50, roleLabel: 'LWB'),
      _S(index: 5, defaultPosition: PlayerPosition.cmf, x: 0.38, y: 0.55, roleLabel: 'LCMF'),
      _S(index: 6, defaultPosition: PlayerPosition.cmf, x: 0.62, y: 0.55, roleLabel: 'RCMF'),
      _S(index: 7, defaultPosition: PlayerPosition.rmf, x: 0.88, y: 0.50, roleLabel: 'RWB'),
      _S(index: 8, defaultPosition: PlayerPosition.amf, x: 0.50, y: 0.36, roleLabel: 'AMF'),
      _S(index: 9, defaultPosition: PlayerPosition.cf, x: 0.38, y: 0.18, roleLabel: 'LCF'),
      _S(index: 10, defaultPosition: PlayerPosition.cf, x: 0.62, y: 0.18, roleLabel: 'RCF'),
    ],
    FormationType.f3421 => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.cb, x: 0.26, y: 0.75, roleLabel: 'LCB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.50, y: 0.78, roleLabel: 'CB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.74, y: 0.75, roleLabel: 'RCB'),
      _S(index: 4, defaultPosition: PlayerPosition.lmf, x: 0.12, y: 0.50, roleLabel: 'LWB'),
      _S(index: 5, defaultPosition: PlayerPosition.cmf, x: 0.38, y: 0.56, roleLabel: 'LCMF'),
      _S(index: 6, defaultPosition: PlayerPosition.cmf, x: 0.62, y: 0.56, roleLabel: 'RCMF'),
      _S(index: 7, defaultPosition: PlayerPosition.rmf, x: 0.88, y: 0.50, roleLabel: 'RWB'),
      _S(index: 8, defaultPosition: PlayerPosition.amf, x: 0.34, y: 0.33, roleLabel: 'LAMF'),
      _S(index: 9, defaultPosition: PlayerPosition.amf, x: 0.66, y: 0.33, roleLabel: 'RAMF'),
      _S(index: 10, defaultPosition: PlayerPosition.cf, x: 0.50, y: 0.16, roleLabel: 'CF'),
    ],
    FormationType.f541 => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.lb, x: 0.11, y: 0.68, roleLabel: 'LWB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.30, y: 0.77, roleLabel: 'LCB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.50, y: 0.79, roleLabel: 'CB'),
      _S(index: 4, defaultPosition: PlayerPosition.cb, x: 0.70, y: 0.77, roleLabel: 'RCB'),
      _S(index: 5, defaultPosition: PlayerPosition.rb, x: 0.89, y: 0.68, roleLabel: 'RWB'),
      _S(index: 6, defaultPosition: PlayerPosition.lmf, x: 0.18, y: 0.48, roleLabel: 'LMF'),
      _S(index: 7, defaultPosition: PlayerPosition.cmf, x: 0.40, y: 0.52, roleLabel: 'LCMF'),
      _S(index: 8, defaultPosition: PlayerPosition.cmf, x: 0.60, y: 0.52, roleLabel: 'RCMF'),
      _S(index: 9, defaultPosition: PlayerPosition.rmf, x: 0.82, y: 0.48, roleLabel: 'RMF'),
      _S(index: 10, defaultPosition: PlayerPosition.cf, x: 0.50, y: 0.20, roleLabel: 'CF'),
    ],
    FormationType.f4321 => const [
      _gk,
      _S(index: 1, defaultPosition: PlayerPosition.lb, x: 0.14, y: 0.72, roleLabel: 'LB'),
      _S(index: 2, defaultPosition: PlayerPosition.cb, x: 0.38, y: 0.76, roleLabel: 'CB'),
      _S(index: 3, defaultPosition: PlayerPosition.cb, x: 0.62, y: 0.76, roleLabel: 'CB'),
      _S(index: 4, defaultPosition: PlayerPosition.rb, x: 0.86, y: 0.72, roleLabel: 'RB'),
      _S(index: 5, defaultPosition: PlayerPosition.cmf, x: 0.30, y: 0.54, roleLabel: 'LCMF'),
      _S(index: 6, defaultPosition: PlayerPosition.dmf, x: 0.50, y: 0.58, roleLabel: 'DMF'),
      _S(index: 7, defaultPosition: PlayerPosition.cmf, x: 0.70, y: 0.54, roleLabel: 'RCMF'),
      _S(index: 8, defaultPosition: PlayerPosition.ss, x: 0.36, y: 0.32, roleLabel: 'LSS'),
      _S(index: 9, defaultPosition: PlayerPosition.ss, x: 0.64, y: 0.32, roleLabel: 'RSS'),
      _S(index: 10, defaultPosition: PlayerPosition.cf, x: 0.50, y: 0.16, roleLabel: 'CF'),
    ],
  };
}

enum BuildUpStyle {
  short('Qisqa pas'),
  mixed('Aralash'),
  long('Uzun pas');

  const BuildUpStyle(this._label);
  final String _label;
  String get label => tr(_label);
}

enum AttackingArea {
  wide('Qanotlar'),
  balanced('Muvozanat'),
  centre('Markaz');

  const AttackingArea(this._label);
  final String _label;
  String get label => tr(_label);
}

enum DefensiveApproach {
  frontlinePressure('Frontline Pressure'),
  balanced('Muvozanat'),
  allOutDefence('All-out Defence');

  const DefensiveApproach(this._label);
  final String _label;
  String get label => tr(_label);
}

enum ContainmentArea {
  middle('Markazni yopish'),
  wide('Qanotlarni yopish');

  const ContainmentArea(this._label);
  final String _label;
  String get label => tr(_label);
}

/// Jamoa taktik konfiguratsiyasi
class TeamTactics {
  final FormationType formation;
  final TeamPlaystyle playstyle;
  final int defensiveLine; // 1 (juda past) – 5 (juda baland)
  final int attackingIntensity; // 1 – 5
  final int tempo;
  final int width;
  final int pressing;
  final bool counterPress;
  final bool playOutFromBack;
  final bool offsideTrap;
  final BuildUpStyle buildUp;
  final AttackingArea attackingArea;
  final DefensiveApproach defensiveApproach;
  final ContainmentArea containment;
  final int compactness;
  final bool flexiblePositioning;
  final bool timeWasting;
  const TeamTactics({
    this.formation = FormationType.f433,
    this.playstyle = TeamPlaystyle.possession,
    this.defensiveLine = 3,
    this.attackingIntensity = 3,
    this.tempo = 3,
    this.width = 3,
    this.pressing = 3,
    this.counterPress = false,
    this.playOutFromBack = true,
    this.offsideTrap = false,
    this.buildUp = BuildUpStyle.mixed,
    this.attackingArea = AttackingArea.balanced,
    this.defensiveApproach = DefensiveApproach.balanced,
    this.containment = ContainmentArea.middle,
    this.compactness = 3,
    this.flexiblePositioning = false,
    this.timeWasting = false,
  });
  TeamTactics copyWith({
    FormationType? formation,
    TeamPlaystyle? playstyle,
    int? defensiveLine,
    int? attackingIntensity,
    int? tempo,
    int? width,
    int? pressing,
    bool? counterPress,
    bool? playOutFromBack,
    bool? offsideTrap,
    BuildUpStyle? buildUp,
    AttackingArea? attackingArea,
    DefensiveApproach? defensiveApproach,
    ContainmentArea? containment,
    int? compactness,
    bool? flexiblePositioning,
    bool? timeWasting,
  }) {
    return TeamTactics(
      formation: formation ?? this.formation,
      playstyle: playstyle ?? this.playstyle,
      defensiveLine: defensiveLine ?? this.defensiveLine,
      attackingIntensity: attackingIntensity ?? this.attackingIntensity,
      tempo: tempo ?? this.tempo,
      width: width ?? this.width,
      pressing: pressing ?? this.pressing,
      counterPress: counterPress ?? this.counterPress,
      playOutFromBack: playOutFromBack ?? this.playOutFromBack,
      offsideTrap: offsideTrap ?? this.offsideTrap,
      buildUp: buildUp ?? this.buildUp,
      attackingArea: attackingArea ?? this.attackingArea,
      defensiveApproach: defensiveApproach ?? this.defensiveApproach,
      containment: containment ?? this.containment,
      compactness: compactness ?? this.compactness,
      flexiblePositioning: flexiblePositioning ?? this.flexiblePositioning,
      timeWasting: timeWasting ?? this.timeWasting,
    );
  }

  Map<String, dynamic> toMap() => {
    'formation': formation.name,
    'playstyle': playstyle.name,
    'defensiveLine': defensiveLine,
    'attackingIntensity': attackingIntensity,
    'tempo': tempo,
    'width': width,
    'pressing': pressing,
    'counterPress': counterPress,
    'playOutFromBack': playOutFromBack,
    'offsideTrap': offsideTrap,
    'buildUp': buildUp.name,
    'attackingArea': attackingArea.name,
    'defensiveApproach': defensiveApproach.name,
    'containment': containment.name,
    'compactness': compactness,
    'flexiblePositioning': flexiblePositioning,
    'timeWasting': timeWasting,
  };

  factory TeamTactics.fromMap(Map t) => TeamTactics(
    formation: FormationType.values.byName(t['formation']),
    playstyle: TeamPlaystyle.values.byName(t['playstyle']),
    defensiveLine: t['defensiveLine'] ?? 3,
    attackingIntensity: t['attackingIntensity'] ?? 3,
    tempo: t['tempo'] ?? 3,
    width: t['width'] ?? 3,
    pressing: t['pressing'] ?? 3,
    counterPress: t['counterPress'] ?? false,
    playOutFromBack: t['playOutFromBack'] ?? true,
    offsideTrap: t['offsideTrap'] ?? false,
    buildUp: BuildUpStyle.values.asNameMap()[t['buildUp']] ?? BuildUpStyle.mixed,
    attackingArea:
        AttackingArea.values.asNameMap()[t['attackingArea']] ?? AttackingArea.balanced,
    defensiveApproach:
        DefensiveApproach.values.asNameMap()[t['defensiveApproach']] ??
        DefensiveApproach.balanced,
    containment:
        ContainmentArea.values.asNameMap()[t['containment']] ?? ContainmentArea.middle,
    compactness: t['compactness'] ?? 3,
    flexiblePositioning: t['flexiblePositioning'] ?? false,
    timeWasting: t['timeWasting'] ?? false,
  );
}

/// Klub Modeli
class Club {
  static const matchdayBench = 9;
  final String id;
  final String name;
  final String shortName;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final String stadiumName;
  int stadiumCapacity; // grows with stadium upgrades
  final String city;
  final String nickname;
  final int founded;
  int reputation; // 1–100: tijorat daromadi, kutilmalar
  int transferBudget; // EUR
  int wageBudget; // Haftalik limit (EUR)
  int ticketPrice; // o‘rtacha chipta narxi (EUR)
  int fanMood; // 0–100
  String? captainId, cornerTakerId, freeKickTakerId, penaltyTakerId;
  String managerName;
  TeamTactics tactics;
  final ClubCrestConfig crestConfig;
  List<Player> squad;
  List<String> startingLineupIds;
  List<String> benchIds; // O‘yin kuni zaxirasi (≤ 9)
  Club({
    required this.id,
    required this.name,
    required this.shortName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.stadiumName,
    required this.stadiumCapacity,
    required this.transferBudget,
    required this.wageBudget,
    required this.tactics,
    required this.crestConfig,
    required this.squad,
    required this.startingLineupIds,
    required this.benchIds,
    this.city = '',
    this.nickname = '',
    this.founded = 1900,
    this.reputation = 75,
    this.ticketPrice = 70,
    this.fanMood = 70,
    this.captainId,
    this.cornerTakerId,
    this.freeKickTakerId,
    this.penaltyTakerId,
    this.managerName = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'shortName': shortName,
    'primaryColor': primaryColor.toARGB32(),
    'secondaryColor': secondaryColor.toARGB32(),
    'accentColor': accentColor.toARGB32(),
    'stadiumName': stadiumName,
    'stadiumCapacity': stadiumCapacity,
    'city': city,
    'nickname': nickname,
    'founded': founded,
    'reputation': reputation,
    'transferBudget': transferBudget,
    'wageBudget': wageBudget,
    'ticketPrice': ticketPrice,
    'fanMood': fanMood,
    'captainId': captainId,
    'cornerTakerId': cornerTakerId,
    'freeKickTakerId': freeKickTakerId,
    'penaltyTakerId': penaltyTakerId,
    'managerName': managerName,
    'tactics': tactics.toMap(),
    'crest': crestConfig.toMap(),
    'squad': squad.map((p) => p.toMap()).toList(),
    'startingLineupIds': startingLineupIds,
    'benchIds': benchIds,
  };

  factory Club.fromMap(Map<String, dynamic> m) => Club(
    id: m['id'],
    name: m['name'],
    shortName: m['shortName'],
    primaryColor: Color(m['primaryColor']),
    secondaryColor: Color(m['secondaryColor']),
    accentColor: Color(m['accentColor']),
    stadiumName: m['stadiumName'],
    stadiumCapacity: m['stadiumCapacity'],
    city: m['city'] ?? '',
    nickname: m['nickname'] ?? '',
    founded: m['founded'] ?? 1900,
    reputation: m['reputation'] ?? 75,
    transferBudget: m['transferBudget'],
    wageBudget: m['wageBudget'],
    ticketPrice: m['ticketPrice'] ?? 70,
    fanMood: m['fanMood'] ?? 70,
    captainId: m['captainId'],
    cornerTakerId: m['cornerTakerId'],
    freeKickTakerId: m['freeKickTakerId'],
    penaltyTakerId: m['penaltyTakerId'],
    managerName: m['managerName'] ?? '',
    tactics: TeamTactics.fromMap(m['tactics'] as Map),
    crestConfig: ClubCrestConfig.fromMap(m['crest'] as Map),
    squad: (m['squad'] as List)
        .map((p) => Player.fromMap(Map<String, dynamic>.from(p)))
        .toList(),
    startingLineupIds: List<String>.from(m['startingLineupIds']),
    benchIds: List<String>.from(m['benchIds']),
  );

  Player? playerById(String id) => squad.where((p) => p.id == id).firstOrNull;

  /// Asosiy 11 ta o'yinchi (slot tartibida)
  List<Player> get startingXI => startingLineupIds
      .map(playerById)
      .whereType<Player>()
      .toList();

  /// O‘yin kuni zaxirasi
  List<Player> get bench =>
      benchIds.map(playerById).whereType<Player>().toList();

  /// Tarkibdan tashqaridagi futbolchilar (rezerv)
  List<Player> get reserves => squad
      .where(
        (p) => !startingLineupIds.contains(p.id) && !benchIds.contains(p.id),
      )
      .toList();

  PlayerPosition slotPosition(int i) {
    final slots = tactics.formation.slots;
    return i < slots.length ? slots[i].defaultPosition : PlayerPosition.cmf;
  }

  /// Jamoaning umumiy OVR (asosiy 11 ning amaliy o‘rtachasi)
  int get teamOVR {
    final xi = startingXI;
    if (xi.isEmpty) return 70;
    var sum = 0;
    for (var i = 0; i < xi.length; i++) {
      sum += xi[i].getMatchOVR(slotPosition(i));
    }
    return (sum / xi.length).round();
  }

  int _lineRating(bool Function(PlayerPosition) test) {
    final xi = startingXI;
    var sum = 0, n = 0;
    for (var i = 0; i < xi.length; i++) {
      final pos = slotPosition(i);
      if (test(pos)) {
        sum += xi[i].getEffectiveOVR(pos);
        n++;
      }
    }
    return n == 0 ? 70 : (sum / n).round();
  }

  int get attackRating => _lineRating((p) => p.isAttacker);
  int get midfieldRating => _lineRating((p) => p.isMidfielder);
  int get defenseRating => _lineRating((p) => p.isDefender || p.isGoalkeeper);

  /// Butun tarkib kuchi (chuqurlik) – eng yaxshi 18 ning o‘rtachasi
  int get squadDepthRating {
    final ovr = squad.map((p) => p.ovr).toList()..sort((a, b) => b - a);
    final top = ovr.take(18).toList();
    if (top.isEmpty) return 70;
    return (top.reduce((a, b) => a + b) / top.length).round();
  }

  int get totalWeeklyWages =>
      squad.fold<int>(0, (sum, p) => sum + p.contract.weeklyWage);
  int get remainingWageBudget => wageBudget - totalWeeklyWages;
  int get squadValue => squad.fold<int>(0, (s, p) => s + p.marketValue);
  double get averageAge => squad.isEmpty
      ? 0
      : squad.fold<int>(0, (s, p) => s + p.age) / squad.length;

  String get formattedTransferBudget =>
      '€${(transferBudget / 1000000).toStringAsFixed(1)}M';
  String get formattedWageBudget =>
      trf('€{0}K/hft', [(wageBudget / 1000).toStringAsFixed(0)]);
}
