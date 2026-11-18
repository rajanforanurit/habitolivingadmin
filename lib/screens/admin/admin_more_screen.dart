import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import '../change_password_screen.dart';
import '../documents_screen.dart';
import '../emergency_screen.dart';
import '../lost_found_screen.dart';
import '../audit_log_screen.dart';
import '../notifications_inbox_screen.dart';
import '../settings_screen.dart';
import 'charges_screen.dart';
import 'expenses_screen.dart';
import 'administrators_screen.dart';
import 'gates_screen.dart';
import 'guards_screen.dart';
import '../calls/call_contacts_screen.dart';
import 'community_moderation_screen.dart';
import 'emergency_alarms_screen.dart';
import 'helpdesk_screen.dart';
import 'platform_monitor_screen.dart';
import 'society_info_screen.dart';
import 'vehicles_parking_screen.dart';
import 'amenities_screen.dart';
import 'marketplace_admin_screen.dart';
import 'property_admin_screen.dart';
import 'polls_screen.dart';
import 'posts_screen.dart';
import 'incidents_screen.dart';
import 'emergency_contacts_screen.dart';
import 'setup/roles_screen.dart';
import 'setup/staff_screen.dart';
import 'setup/vendors_screen.dart';

/// Everything that is not an everyday job.
///
/// The five tabs are what an admin opens daily. This screen is what they open
/// when the building itself changes: a new tower, a new gate, a new role, a new
/// vendor. Keeping that out of the tabs means the daily screens stay short, and
/// the setup work is one place instead of six menus.
class AdminMoreScreen extends StatelessWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppServices.instance.session;
    final name = session.displayName;

    return AppScaffold(
      title: 'More',
      subtitle: 'Your society',
      body: ListView(
        padding: const EdgeInsets.only(bottom: Tokens.space8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: _ProfileCard(
              name: name,
              email: currentIdentity()?.user.email ?? '',
              mobile: currentIdentity()?.user.mobile ?? '',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ),

          const SizedBox(height: Tokens.space6),
          const SectionLabel('Building'),
          const SizedBox(height: Tokens.space2),
          Panel(
            margin: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Column(
              children: [
                ListRow(
                  title: 'Property details',
                  subtitle: 'Towers, units, floor plans and hospitals (set by the platform team)',
                  icon: Icons2.property,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SocietyInfoScreen()),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Roles and permissions',
                  subtitle: 'What each role can do',
                  icon: Icons2.roles,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RolesScreen()),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Gates',
                  subtitle: 'Where guards are posted',
                  icon: Icons2.gate,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GatesScreen()),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Guards',
                  subtitle: 'Who watches the gates',
                  icon: Icons2.guard,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GuardsScreen()),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Staff',
                  subtitle: 'Helpers the society employs',
                  icon: Icons2.staff,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StaffScreen()),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Vendors',
                  subtitle: 'Who the society hires',
                  icon: Icons2.vendors,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VendorsScreen()),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Administrators',
                  subtitle: 'Who else can run the society',
                  icon: Icons2.administrators,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdministratorsScreen(),
                    ),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Amenities',
                  subtitle: 'Gym, clubhouse, pool — and bookings',
                  icon: Icons2.amenities,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AmenitiesScreen()),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Vehicles & parking',
                  subtitle: 'Vehicles, slots and requests',
                  icon: Icons2.vehicles,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const VehiclesParkingScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Tokens.space6),
          const SectionLabel('Safety and communication'),
          const SizedBox(height: Tokens.space2),
          Panel(
            margin: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Column(
              children: [
                ListRow(
                  title: 'Emergencies',
                  subtitle: 'Live alarms, who raised them, responses',
                  icon: Icons2.panic,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EmergencyAlarmsScreen()),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Helpdesk',
                  subtitle: 'Plumber, mechanic, doctor and other numbers',
                  icon: Icons2.directory,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpdeskScreen()),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Calls',
                  subtitle: 'Call residents and guards in the app',
                  icon: Icons2.phone,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CallContactsScreen()),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Platform',
                  subtitle: 'Sign-ins and access errors in your society',
                  icon: Icons2.monitoring,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlatformMonitorScreen()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Tokens.space6),
          const SectionLabel('Money'),
          const SizedBox(height: Tokens.space2),
          Panel(
            margin: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Column(
              children: [
                ListRow(
                  title: 'Charges',
                  subtitle: 'What the society bills for',
                  icon: Icons2.finance,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChargesScreen()),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Expenses',
                  subtitle: 'What was spent',
                  icon: Icons2.reports,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ExpensesScreen()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Tokens.space6),
          const SectionLabel('Shared'),
          const SizedBox(height: Tokens.space2),
          Panel(
            margin: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Column(
              children: [
                ListRow(
                  title: 'Documents',
                  subtitle: 'Society documents and notices',
                  icon: Icons2.documents,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DocumentsScreen()),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Emergency contacts',
                  subtitle: 'The numbers residents dial',
                  icon: Icons2.emergency,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EmergencyContactsScreen(),
                    ),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Incidents',
                  subtitle: 'Security reports and their status',
                  icon: Icons2.incidents,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const IncidentsScreen()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Tokens.space6),
          const SectionLabel('Community'),
          const SizedBox(height: Tokens.space2),
          Panel(
            margin: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Column(
              children: [
                ListRow(
                  title: 'Marketplace',
                  subtitle: 'Listings, categories and reports',
                  icon: Icons2.marketplace,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MarketplaceAdminScreen(),
                    ),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Property',
                  subtitle: 'Property listings and reports',
                  icon: Icons2.property,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PropertyAdminScreen(),
                    ),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Polls',
                  subtitle: 'Ask the society, count the votes',
                  icon: Icons2.poll,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PollsScreen()),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Community posts',
                  subtitle: 'Review pending, approved and rejected posts',
                  icon: Icons2.community,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CommunityModerationScreen(),
                    ),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Published posts',
                  subtitle: 'Remove a post that is already live',
                  icon: Icons2.community,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PostsScreen()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Tokens.space6),
          const SectionLabel('On site'),
          const SizedBox(height: Tokens.space2),
          Panel(
            margin: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Column(
              children: [
                ListRow(
                  title: 'Audit log',
                  subtitle: 'Everything that happened, with names',
                  icon: Icons2.audit,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AuditLogScreen(
                        fetch: AppServices.instance.admin.auditLogs,
                      ),
                    ),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Emergency numbers',
                  subtitle: 'One tap to call',
                  icon: Icons2.emergency,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EmergencyScreen()),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Lost and found',
                  subtitle: 'What has been handed in',
                  icon: Icons2.lostFound,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LostFoundScreen()),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Notifications',
                  subtitle: 'Everything sent to residents',
                  icon: Icons2.notifications,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsInboxScreen(),
                    ),
                  ),
                ),
                const Hairline(),
                ListRow(
                  title: 'Change password',
                  subtitle: 'How you sign in',
                  icon: Icons2.password,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.mobile,
    required this.onTap,
  });

  final String name;
  final String email;
  final String mobile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      color: Tokens.accent,
      child: Row(
        children: [
          InitialsAvatar(name: name, size: 44),
          SizedBox(width: Tokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeBase,
                    fontWeight: FontWeight.w600,
                    color: Tokens.accentOn,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  [
                    if (email.isNotEmpty) email,
                    mobile,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeXs,
                    color: Tokens.accentOn.withValues(alpha: 0.75),
                  ),
                ),
                SizedBox(height: Tokens.space1),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Tokens.space2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Tokens.accentOn.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(Tokens.radiusFull),
                  ),
                  child: Text(
                    'Society admin',
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Tokens.accentOn,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppIcon(Icons2.forward, size: IconSize.row, color: Tokens.accentOn),
        ],
      ),
    );
  }
}
