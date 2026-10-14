import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _kRagsproUrl = 'https://www.ragspro.com/?utm_source=grazia_stones_app&utm_medium=app_footer';

/// App version line plus "Powered by RAGSPRO" which opens the agency website.
class PoweredByRagspro extends StatelessWidget {
  final Color textColor;
  final Color accentColor;

  const PoweredByRagspro({super.key, required this.textColor, required this.accentColor});

  Future<void> _open(BuildContext context) async {
    HapticFeedback.selectionClick();
    final ok = await launchUrl(Uri.parse(_kRagsproUrl), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open ragspro.com')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snap) {
            final v = snap.data;
            return Text(
              v == null ? 'Grazia Stones' : 'Grazia Stones v${v.version} (${v.buildNumber})',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: textColor),
            );
          },
        ),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: 'Powered by RAGSPRO, opens ragspro.com',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _open(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text.rich(
                TextSpan(
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: textColor),
                  children: [
                    const TextSpan(text: 'Powered by '),
                    TextSpan(
                      text: 'RAGSPRO',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: accentColor,
                        decoration: TextDecoration.underline,
                        decorationColor: accentColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
