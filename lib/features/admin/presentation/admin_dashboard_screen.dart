import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/features/admin/presentation/widgets/admin_module_switcher.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, int> _n = const {};

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _isLoading = _n.isEmpty;
      _error = null;
    });
    try {
      final c = SupabaseService.instance.client;
      // Count-only queries, fired together: one round trip's worth of latency, no rows downloaded.
      final q = <String, Future<int>>{
        'products': c.from('stones').count(),
        'live': c.from('stones').count().eq('active', true),
        'collections': c.from('collections').count(),
        'orders': c.from('orders').count(),
        'ordersPending': c.from('orders').count().eq('status', 'pending'),
        'quotes': c.from('quote_requests').count(),
        'quotesPending': c.from('quote_requests').count().eq('status', 'pending'),
        'samples': c.from('sample_requests').count(),
        'samplesPending': c.from('sample_requests').count().eq('status', 'pending'),
        'aiQueued': c.from('ai_jobs').count().inFilter('status', ['queued', 'processing']),
        'dealers': c.from('dealers').count(),
        'clients': c.from('profiles').count(),
      };
      final values = await Future.wait(q.values);
      if (mounted) {
        setState(() {
          _n = Map.fromIterables(q.keys, values);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showRegisteredClientsSheet(BuildContext context, LuxuryPalette palette) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _RegisteredClientsModalSheet(
        palette: palette,
        onRoleChanged: () => _loadMetrics(),
      ),
    );
  }

  String _pending(String total, String pending, String noun) {
    final p = _n[pending] ?? 0;
    return p > 0 ? '$p pending' : '${_n[total] ?? 0} $noun';
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    void go(String route) {
      HapticFeedback.lightImpact();
      context.push(route).then((_) => _loadMetrics());
    }

    final hidden = (_n['products'] ?? 0) - (_n['live'] ?? 0);
    final sections = <(String, List<_Tile>)>[
      ('Catalogue', [
        _Tile('Products', hidden > 0 ? '${_n['products']} · $hidden hidden' : '${_n['products'] ?? 0} items', Icons.diamond_outlined, () => go('/admin/products')),
        _Tile('Collections', '${_n['collections'] ?? 0} series', Icons.grid_view_rounded, () => go('/admin/collections')),
        _Tile('Add product', 'New stone', Icons.add_rounded, () => go('/admin/products/add'), accent: true),
      ]),
      ('Sales', [
        _Tile('Orders', _pending('orders', 'ordersPending', 'total'), Icons.local_shipping_outlined, () => go('/admin/orders')),
        _Tile('Quotes', _pending('quotes', 'quotesPending', 'total'), Icons.request_quote_outlined, () => go('/admin/quotes')),
        _Tile('Samples', _pending('samples', 'samplesPending', 'total'), Icons.layers_outlined, () => go('/admin/samples')),
      ]),
      ('AI Studio', [
        _Tile('AI jobs', (_n['aiQueued'] ?? 0) > 0 ? '${_n['aiQueued']} in queue' : 'Queue clear', Icons.auto_awesome_outlined, () => go('/admin/ai-jobs')),
        _Tile('AI usage', 'Per user', Icons.insights_outlined, () => go('/admin/ai-usage')),
        _Tile('Plans', 'Plus / Pro', Icons.workspace_premium_outlined, () => go('/admin/plans')),
      ]),
      ('People', [
        _Tile('Dealers', '${_n['dealers'] ?? 0} showrooms', Icons.storefront_outlined, () => go('/admin/dealers')),
        _Tile('Clients', '${_n['clients'] ?? 0} accounts', Icons.people_outline_rounded, () => _showRegisteredClientsSheet(context, palette)),
      ]),
    ];

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text('Admin', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700, color: palette.textPrimary)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadMetrics();
            },
            icon: Icon(Icons.refresh_rounded, color: palette.primary),
          ),
          AdminQuickNavButton(currentRoute: '/admin/dashboard', palette: palette),
          const SizedBox(width: 6),
        ],
      ),
      body: _error != null
          ? ErrorHandlerWidget(error: Exception(_error), onRetry: _loadMetrics)
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : RefreshIndicator(
                  color: palette.primary,
                  backgroundColor: palette.surface,
                  onRefresh: _loadMetrics,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                        children: [
                          _Overview(palette: palette, figures: [
                            _Figure('${_n['live'] ?? 0}', 'Live products', () => go('/admin/products?status=active')),
                            _Figure('${_n['quotesPending'] ?? 0}', 'Open quotes', () => go('/admin/quotes?status=pending')),
                            _Figure('${_n['samplesPending'] ?? 0}', 'Sample requests', () => go('/admin/samples?status=pending')),
                            _Figure('${_n['ordersPending'] ?? 0}', 'Pending orders', () => go('/admin/orders?status=pending')),
                          ]),
                          for (final (title, tiles) in sections) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
                              child: Text(title,
                                  style: GoogleFonts.playfairDisplay(fontSize: 15, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                            ),
                            LayoutBuilder(builder: (context, box) {
                              final cols = box.maxWidth >= 600 ? 4 : 3;
                              const gap = 8.0;
                              final w = (box.maxWidth - gap * (cols - 1)) / cols;
                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: [for (final t in tiles) SizedBox(width: w, child: _TileView(tile: t, palette: palette))],
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}

class _Figure {
  final String value;
  final String label;
  final VoidCallback onTap;
  const _Figure(this.value, this.label, this.onTap);
}

/// One panel, four figures split by hairlines — reads as a single summary, not four more boxes.
class _Overview extends StatelessWidget {
  final LuxuryPalette palette;
  final List<_Figure> figures;
  const _Overview({required this.palette, required this.figures});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 3, color: palette.primary),
          IntrinsicHeight(
            child: Row(
              children: [
                for (var i = 0; i < figures.length; i++) ...[
                  if (i > 0) VerticalDivider(width: 1, thickness: 1, color: palette.border, indent: 12, endIndent: 12),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: '${figures[i].value} ${figures[i].label}',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: figures[i].onTap,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 12, 6, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(figures[i].value,
                                    style: GoogleFonts.playfairDisplay(
                                        fontSize: 24, height: 1.1, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                              ),
                              const SizedBox(height: 4),
                              Text(figures[i].label,
                                  maxLines: 2,
                                  style: GoogleFonts.inter(fontSize: 11, height: 1.25, color: palette.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile {
  final String title;
  final String caption;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;
  const _Tile(this.title, this.caption, this.icon, this.onTap, {this.accent = false});
}

class _TileView extends StatelessWidget {
  final _Tile tile;
  final LuxuryPalette palette;
  const _TileView({required this.tile, required this.palette});

  @override
  Widget build(BuildContext context) {
    final fg = tile.accent ? palette.primary : palette.textPrimary;
    return Material(
      color: tile.accent ? palette.primary.withValues(alpha: 0.08) : palette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 84,
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tile.accent ? palette.primary.withValues(alpha: 0.5) : palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(tile.icon, size: 20, color: palette.primary),
              const Spacer(),
              Text(tile.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
              const SizedBox(height: 1),
              Text(tile.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisteredClientsModalSheet extends StatefulWidget {
  final LuxuryPalette palette;
  final VoidCallback onRoleChanged;

  const _RegisteredClientsModalSheet({
    required this.palette,
    required this.onRoleChanged,
  });

  @override
  State<_RegisteredClientsModalSheet> createState() => _RegisteredClientsModalSheetState();
}

class _RegisteredClientsModalSheetState extends State<_RegisteredClientsModalSheet> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _profiles = [];
  String _selectedRole = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final client = SupabaseService.instance.client;
      final data = await client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _profiles = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _changeUserRole(String userId, String currentRole, String userName) async {
    final availableRoles = ['user', 'architect', 'dealer', 'admin'];
    String chosenRole = currentRole;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            backgroundColor: widget.palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: widget.palette.border),
            ),
            title: Text(
              'Change Client Role',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w700,
                color: widget.palette.textPrimary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User: $userName',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Select new access privilege:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: widget.palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableRoles.map((r) {
                    final isSel = chosenRole == r;
                    return ChoiceChip(
                      label: Text(r.toUpperCase()),
                      selected: isSel,
                      selectedColor: widget.palette.primary,
                      backgroundColor: widget.palette.surface,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : widget.palette.textPrimary,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setDlgState(() => chosenRole = r);
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: widget.palette.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.palette.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  'Update Role',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && chosenRole != currentRole) {
      try {
        final client = SupabaseService.instance.client;
        await client
            .from('profiles')
            .update({'role': chosenRole, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', userId);

        if (mounted) {
          LuxuryToast.show(context, message: 'Role updated to ${chosenRole.toUpperCase()}');
          _loadProfiles();
          widget.onRoleChanged();
        }
      } catch (e) {
        if (mounted) {
          LuxuryToast.show(context, message: 'Failed: $e');
        }
      }
    }
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purpleAccent;
      case 'architect':
        return Colors.blueAccent;
      case 'dealer':
        return Colors.amber.shade700;
      default:
        return widget.palette.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _profiles.where((p) {
      final role = (p['role'] ?? 'user').toString().toLowerCase();
      if (_selectedRole != 'all' && role != _selectedRole.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (p['full_name'] ?? '').toString().toLowerCase();
        final email = (p['email'] ?? '').toString().toLowerCase();
        final phone = (p['phone'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !email.contains(q) && !phone.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.palette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registered Clients',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: widget.palette.textPrimary,
                        ),
                      ),
                      Text(
                        '${_profiles.length} total users in Supabase profiles',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: widget.palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadProfiles,
                  tooltip: 'Refresh list',
                  icon: Icon(Icons.refresh_rounded, color: widget.palette.primary, size: 20),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: widget.palette.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.inter(color: widget.palette.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by client name, email or phone...',
                hintStyle: GoogleFonts.inter(color: widget.palette.textTertiary, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: widget.palette.textTertiary),
                filled: true,
                fillColor: widget.palette.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.palette.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Role Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: ['all', 'admin', 'architect', 'dealer', 'user'].map((role) {
                final isSelected = _selectedRole == role;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedRole = role);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? widget.palette.primary : widget.palette.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? widget.palette.primary : widget.palette.border,
                        ),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : widget.palette.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: widget.palette.border),

          // Users List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(widget.palette.primary),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No clients match the current filter',
                              style: GoogleFonts.inter(
                                color: widget.palette.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final u = filtered[index];
                              final id = (u['id'] ?? '').toString();
                              final name = (u['full_name'] ?? 'Anonymous Client').toString();
                              final email = (u['email'] ?? 'No email').toString();
                              final phone = (u['phone'] ?? '').toString();
                              final role = (u['role'] ?? 'user').toString();
                              final createdAt = u['created_at'] != null
                                  ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(u['created_at'].toString()) ?? DateTime.now())
                                  : 'Recently';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: widget.palette.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: widget.palette.border),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: widget.palette.primary.withValues(alpha: 0.12),
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          color: widget.palette.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name,
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color: widget.palette.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _roleColor(role).withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: _roleColor(role).withValues(alpha: 0.4),
                                                  ),
                                                ),
                                                child: Text(
                                                  role.toUpperCase(),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: _roleColor(role),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            email,
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              color: widget.palette.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (phone.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              phone,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: widget.palette.textTertiary,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Text(
                                            'Joined: $createdAt',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: widget.palette.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Change Role',
                                      onPressed: () => _changeUserRole(id, role, name),
                                      icon: Icon(Icons.manage_accounts_outlined, color: widget.palette.primary, size: 20),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
