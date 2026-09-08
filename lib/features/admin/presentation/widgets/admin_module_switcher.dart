import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/shared/theme/colors.dart';

class AdminModuleItem {
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;

  const AdminModuleItem({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
  });
}

const List<AdminModuleItem> kAdminModules = [
  AdminModuleItem(
    title: 'Dashboard Overview',
    subtitle: 'High-level real-time business metrics',
    route: '/admin/dashboard',
    icon: Icons.dashboard_outlined,
  ),
  AdminModuleItem(
    title: 'Product Catalog',
    subtitle: 'Manage stone inventory, pricing & specs',
    route: '/admin/products',
    icon: Icons.diamond_outlined,
  ),
  AdminModuleItem(
    title: 'Curated Collections',
    subtitle: 'Manage stone collections & categories',
    route: '/admin/collections',
    icon: Icons.category_outlined,
  ),
  AdminModuleItem(
    title: 'Orders & Fulfillment',
    subtitle: 'Track client orders & update statuses',
    route: '/admin/orders',
    icon: Icons.local_shipping_outlined,
  ),
  AdminModuleItem(
    title: 'Architectural Quotes',
    subtitle: 'Review & respond to client quote requests',
    route: '/admin/quotes',
    icon: Icons.request_quote_outlined,
  ),
  AdminModuleItem(
    title: 'Sample Dispatches',
    subtitle: 'Manage stone sample box requests',
    route: '/admin/samples',
    icon: Icons.layers_outlined,
  ),
  AdminModuleItem(
    title: 'Authorized Dealers',
    subtitle: 'Experience centers & partner showrooms',
    route: '/admin/dealers',
    icon: Icons.storefront_outlined,
  ),
  AdminModuleItem(
    title: 'AI Studio Jobs',
    subtitle: 'Monitor photorealistic rendering queue',
    route: '/admin/ai-jobs',
    icon: Icons.auto_awesome_rounded,
  ),
];

/// Reusable quick navigation button for the AppBar of all Admin screens.
class AdminQuickNavButton extends StatelessWidget {
  final String currentRoute;
  final LuxuryPalette palette;

  const AdminQuickNavButton({
    super.key,
    required this.currentRoute,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Switch Admin Module',
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: palette.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.primary.withValues(alpha: 0.25)),
        ),
        child: Icon(Icons.apps_rounded, color: palette.primary, size: 18),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: palette.background,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          builder: (ctx) => _AdminModuleModalSheet(
            currentRoute: currentRoute,
            palette: palette,
          ),
        );
      },
    );
  }
}

class _AdminModuleModalSheet extends StatelessWidget {
  final String currentRoute;
  final LuxuryPalette palette;

  const _AdminModuleModalSheet({
    required this.currentRoute,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: bottomPadding + 14,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sheet Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Modules',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quick switch between management consoles',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/home');
                  },
                  icon: Icon(Icons.storefront_outlined, size: 16, color: palette.primary),
                  label: Text(
                    'Client App',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Modules list
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: kAdminModules.length,
                itemBuilder: (context, index) {
                  final module = kAdminModules[index];
                  final isCurrent = currentRoute == module.route;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? palette.primary.withValues(alpha: 0.1)
                          : palette.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrent
                            ? palette.primary
                            : palette.border,
                        width: isCurrent ? 1.5 : 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          if (!isCurrent) {
                            context.push(module.route);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? palette.primary
                                      : palette.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  module.icon,
                                  color: isCurrent ? Colors.white : palette.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      module.title,
                                      style: GoogleFonts.playfairDisplay(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isCurrent ? palette.primary : palette.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      module.subtitle,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: palette.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: palette.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'ACTIVE',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: palette.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: palette.textTertiary,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
