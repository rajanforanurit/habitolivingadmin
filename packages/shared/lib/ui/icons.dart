// `shadcn_flutter` re-exports the Lucide icon set (LucideIcons) and the widget
// layer. Icon sizes and colours are defined at the bottom of this file.
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'tokens.dart';

/// The icon set.
///
/// Lucide ships with shadcn_flutter (1,558 icons) and is the only family used
/// in the app. Every icon is drawn from here so the stroke weight, optical size
/// and colour rule stay consistent:
///
/// - Size: 16 (inline/meta), 18 (row icons), 20 (header/navigation), 24 (hero).
/// - Colour: the icon takes the text role of its container. `iconColor(context)`
///   returns the muted ink, `iconAccent` the accent, `iconDanger` the danger.
/// - Icons never get their own colour in a list row.
class Icons2 {
  Icons2._();

  /// Alias: screens use `email` for a mail field.
  static const IconData email = Icons2.mail;

  // ------------------------------------------------------------ navigation
  static const IconData home = LucideIcons.house;
  static const IconData community = LucideIcons.users;
  static const IconData payments = LucideIcons.receiptText;
  static const IconData help = LucideIcons.lifeBuoy;
  static const IconData profile = LucideIcons.userRound;

  // --------------------------------------------------------------- resident
  static const IconData visitors = LucideIcons.userPlus;
  static const IconData amenities = LucideIcons.dumbbell;
  static const IconData marketplace = LucideIcons.store;
  static const IconData property = LucideIcons.building2;
  static const IconData documents = LucideIcons.fileText;
  static const IconData domesticHelp = LucideIcons.handHeart;
  static const IconData emergency = LucideIcons.siren;
  static const IconData vehicles = LucideIcons.car;
  static const IconData chat = LucideIcons.messageSquare;
  static const IconData directory = LucideIcons.contactRound;
  static const IconData notices = LucideIcons.megaphone;
  static const IconData invoices = LucideIcons.fileSpreadsheet;
  static const IconData complaints = LucideIcons.ticket;

  // ------------------------------------------------------------------ guard
  static const IconData guard = LucideIcons.shieldCheck;
  static const IconData gate = LucideIcons.doorOpen;
  static const IconData deliveries = LucideIcons.package;
  static const IconData lostFound = LucideIcons.search;
  static const IconData incidents = LucideIcons.triangleAlert;
  static const IconData scan = LucideIcons.scanLine;

  // ------------------------------------------------------------------ admin
  static const IconData approvals = LucideIcons.clipboardCheck;
  static const IconData residents = LucideIcons.contactRound;
  static const IconData roles = LucideIcons.keyRound;
  static const IconData finance = LucideIcons.indianRupee;
  static const IconData staff = LucideIcons.briefcaseBusiness;
  static const IconData vendors = LucideIcons.truck;
  static const IconData setup = LucideIcons.settings2;
  static const IconData reports = LucideIcons.chartColumn;
  static const IconData support = LucideIcons.headset;
  static const IconData security = LucideIcons.shieldAlert;
  static const IconData communications = LucideIcons.send;
  static const IconData administrators = LucideIcons.userCog;

  // ------------------------------------------------------------- super admin
  static const IconData societies = LucideIcons.building;
  static const IconData platform = LucideIcons.layoutDashboard;
  static const IconData monitoring = LucideIcons.activity;
  static const IconData audit = LucideIcons.history;
  static const IconData templates = LucideIcons.fileCog;

  // ---------------------------------------------------------------- actions
  static const IconData add = LucideIcons.plus;
  static const IconData edit = LucideIcons.pencil;
  static const IconData delete = LucideIcons.trash2;
  static const IconData save = LucideIcons.check;
  static const IconData cancel = LucideIcons.x;
  static const IconData close = LucideIcons.x;
  static const IconData search = LucideIcons.search;
  static const IconData filter = LucideIcons.listFilter;
  static const IconData refresh = LucideIcons.rotateCw;
  static const IconData more = LucideIcons.ellipsisVertical;
  static const IconData back = LucideIcons.chevronLeft;
  static const IconData forward = LucideIcons.chevronRight;
  static const IconData expand = LucideIcons.chevronDown;
  static const IconData collapse = LucideIcons.chevronUp;
  static const IconData external = LucideIcons.externalLink;
  static const IconData download = LucideIcons.download;
  static const IconData upload = LucideIcons.upload;
  static const IconData camera = LucideIcons.camera;
  static const IconData image = LucideIcons.image;
  static const IconData file = LucideIcons.paperclip;
  static const IconData share = LucideIcons.share2;
  static const IconData logout = LucideIcons.logOut;
  static const IconData settings = LucideIcons.settings;
  static const IconData notifications = LucideIcons.bell;
  static const IconData notificationOff = LucideIcons.bellOff;
  static const IconData theme = LucideIcons.sunMoon;
  static const IconData switchIcon = LucideIcons.arrowLeftRight;

  // ----------------------------------------------------------------- states
  static const IconData empty = LucideIcons.inbox;
  static const IconData error = LucideIcons.circleAlert;
  static const IconData warning = LucideIcons.triangleAlert;
  static const IconData success = LucideIcons.circleCheck;
  static const IconData pending = LucideIcons.clock;
  static const IconData info = LucideIcons.info;
  static const IconData offline = LucideIcons.cloudOff;

  // ------------------------------------------------------------------- misc
  static const IconData flat = LucideIcons.doorClosed;
  static const IconData tower = LucideIcons.building2;
  static const IconData family = LucideIcons.usersRound;
  static const IconData move = LucideIcons.truck;
  static const IconData poll = LucideIcons.chartNoAxesColumn;
  static const IconData like = LucideIcons.thumbsUp;
  static const IconData comment = LucideIcons.messageCircle;
  static const IconData star = LucideIcons.star;
  static const IconData pin = LucideIcons.mapPin;
  static const IconData phone = LucideIcons.phone;
  static const IconData mail = LucideIcons.mail;
  static const IconData password = LucideIcons.lockKeyhole;
  static const IconData visibility = LucideIcons.eye;
  static const IconData visibilityOff = LucideIcons.eyeOff;
  static const IconData calendar = LucideIcons.calendarDays;
  static const IconData clock = LucideIcons.clock;
  static const IconData panic = LucideIcons.siren;
  static const IconData wifiOff = LucideIcons.wifiOff;
}

/// Fixed icon sizes. Anything outside this list is a mistake.
class IconSize {
  IconSize._();

  static const double inline = 16;
  static const double row = 18;
  static const double header = 20;
  static const double hero = 24;
  static const double empty = 32;

  /// Bottom navigation: 22 reads as tappable without crowding the label.
  static const double nav = 22;
}

/// Default icon colour for chrome: the muted ink, so icons sit behind the text.
Color iconColor(BuildContext context) => Tokens.inkFaint;

/// Icon colour for a selected/active item.
Color iconAccent(BuildContext context) => Tokens.accent;

/// Icon colour for a destructive row.
Color iconDanger(BuildContext context) => Tokens.danger;

/// Standard icon widget: sized, coloured by role, with semantics for a11y.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = IconSize.row,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color ?? iconColor(context),
      semanticLabel: semanticLabel,
    );
  }
}

// Convenience aliases used by screens.
extension Icons2Aliases on Icons2 {
  static const IconData email = Icons2.mail;
}
