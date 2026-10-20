import 'package:flutter/widgets.dart';

import '../../theme/icons.dart';
import '../../theme/tokens.dart';

/// Icon and colour per gift, from screen 11. New gifts added in the admin get the box.
(KIcon, Color) giftLook(String slug) => switch (slug) {
  'heart' => (KIcon.heart, KColors.coral),
  'coffee' => (KIcon.coffee, KColors.giftLatte),
  'jollof' => (KIcon.jollof, KColors.giftOrange),
  'star' => (KIcon.star, KColors.gold),
  'talking_drum' => (KIcon.drum, KColors.lilac),
  'vibes' => (KIcon.flame, KColors.coral),
  'crown' => (KIcon.crown, KColors.gold),
  'diamond' => (KIcon.gem, KColors.mint),
  _ => (KIcon.gift, KColors.gold),
};

/// "a Jollof", "an Ice cream".
String withArticle(String name) =>
    '${'aeiou'.contains(name.isEmpty ? 'x' : name[0].toLowerCase()) ? 'an' : 'a'} $name';
