import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/services/room_analysis_service.dart';
import 'package:grazia_stones/shared/theme/colors.dart';

/// Widget for displaying room analysis results
class RoomAnalysisWidget extends StatelessWidget {
  final RoomAnalysisResult analysis;
  final VoidCallback? onWallSelected;
  final VoidCallback? onRetry;
  final LuxuryPalette palette;

  const RoomAnalysisWidget({
    super.key,
    required this.analysis,
    required this.palette,
    this.onWallSelected,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (!analysis.success || !analysis.wallDetected) {
      return _buildErrorState();
    }

    return _buildSuccessState();
  }

  Widget _buildSuccessState() {
    final wall = analysis.bestWall;
    if (wall == null) return _buildErrorState();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wall Surface Detected',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      analysis.message,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Confidence indicator
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Detection Confidence',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: palette.textSecondary,
                          ),
                        ),
                        Text(
                          '${(analysis.confidence * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _getConfidenceColor(analysis.confidence),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: analysis.confidence,
                        backgroundColor: palette.border,
                        valueColor: AlwaysStoppedAnimation(
                          _getConfidenceColor(analysis.confidence),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Walls detected
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Icon(Icons.view_in_ar_outlined, color: palette.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${analysis.walls.length} Wall Surface${analysis.walls.length > 1 ? 's' : ''} Found',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                      if (analysis.objects.isNotEmpty)
                        Text(
                          '${analysis.objects.length} object${analysis.objects.length > 1 ? 's' : ''} detected for occlusion',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: palette.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action button
          if (onWallSelected != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onWallSelected,
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Continue to Visualization'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: palette.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No Wall Surface Detected',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            analysis.error ?? 
            'Please ensure the target architectural surface is well-lit and clearly visible in the photo.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: palette.textSecondary,
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try Another Photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.textPrimary,
                  side: BorderSide(color: palette.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.7) return const Color(0xFF2E7D32); // Green
    if (confidence >= 0.5) return const Color(0xFFF57C00); // Orange
    return const Color(0xFFD32F2F); // Red
  }
}

/// Compact room analysis status indicator
class RoomAnalysisStatusChip extends StatelessWidget {
  final RoomAnalysisResult analysis;
  final LuxuryPalette palette;

  const RoomAnalysisStatusChip({
    super.key,
    required this.analysis,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = analysis.success && analysis.wallDetected;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSuccess 
            ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
            : palette.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSuccess 
              ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
              : palette.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 14,
            color: isSuccess ? const Color(0xFF2E7D32) : palette.primary,
          ),
          const SizedBox(width: 6),
          Text(
            isSuccess 
                ? '${analysis.walls.length} wall${analysis.walls.length > 1 ? 's' : ''} detected'
                : 'No wall detected',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSuccess ? const Color(0xFF2E7D32) : palette.primary,
            ),
          ),
        ],
      ),
    );
  }
}
