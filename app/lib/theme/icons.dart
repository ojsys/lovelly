import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Line icons from the Korram canvas (24 × 24, round caps). Paths copied from the designs.
enum KIcon {
  logo('<circle cx="8" cy="12" r="4"/><circle cx="16" cy="12" r="4"/>'),
  video('<path d="M15 10l5-3v10l-5-3"/><rect x="3" y="6" width="12" height="12" rx="3"/>'),
  mic(
    '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0"/><path d="M12 18v3"/>',
  ),
  chat('<path d="M4 5h16v11H9l-5 4z"/>'),
  person('<circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"/>'),
  arrowRight('<path d="M5 12h14"/><path d="M13 6l6 6-6 6"/>'),
  back('<path d="M15 18l-6-6 6-6"/>'),
  phone(
    '<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2"/>',
  ),
  gift('<rect x="3" y="8" width="18" height="13" rx="2"/><path d="M12 8v13"/><path d="M3 12h18"/>'),
  coin('<path d="M6 3h12l4 6-10 12L2 9z"/><path d="M2 9h20"/>'),
  check('<path d="M20 6L9 17l-5-5"/>'),
  clock('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'),
  shield(
    '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M12 8v5"/><path d="M12 16h.01"/>',
  ),
  close('<path d="M18 6L6 18"/><path d="M6 6l12 12"/>'),
  speaker(
    '<path d="M4 10v4h4l5 4V6L8 10z"/><path d="M16 9a4 4 0 0 1 0 6"/><path d="M19 6a8 8 0 0 1 0 12"/>',
  ),
  micOff(
    '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0"/><path d="M12 18v3"/><path d="M3 3l18 18"/>',
  ),
  videoOff(
    '<path d="M15 10l5-3v10l-5-3"/><rect x="3" y="6" width="12" height="12" rx="3"/><path d="M3 3l18 18"/>',
  ),
  plus('<path d="M12 5v14"/><path d="M5 12h14"/>'),
  search('<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>'),
  addFriend(
    '<circle cx="9" cy="8" r="4"/><path d="M2 21c1-4 4-6 7-6s6 2 7 6"/><path d="M19 8v6"/><path d="M16 11h6"/>',
  );

  const KIcon(this.paths);

  final String paths;
}

class KIconView extends StatelessWidget {
  const KIconView(this.icon, {super.key, this.size = 22, required this.color, this.stroke = 2});

  final KIcon icon;
  final double size;
  final Color color;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
        'stroke="black" stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">'
        '${icon.paths}</svg>';
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
