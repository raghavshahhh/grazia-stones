import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/ai_job.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/features/ai_viz/providers/ai_job_provider.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

/// Shows the 4 variants produced by one "Generate" tap in AI Studio.
/// Each tile reflects its own job's real status — no fake/placeholder
/// images are ever shown; a variant that hasn't completed shows a real
/// loading or error state instead.
class AIResultGalleryScreen extends ConsumerStatefulWidget {
  final String batchId;

  const AIResultGalleryScreen({super.key, required this.batchId});

  @override
  ConsumerState<AIResultGalleryScreen> createState() => _AIResultGalleryScreenState();
}

class _AIResultGalleryScreenState extends ConsumerState<AIResultGalleryScreen> {
  int? _fullscreenVariant;

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final jobsAsync = ref.watch(batchTrackingProvider(widget.batchId));

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('AI Concepts', style: TextStyle(color: palette.textPrimary)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.request_quote_outlined, size: 18),
            label: const Text('Get Quote'),
            onPressed: () {
              final stoneId = jobsAsync.valueOrNull?.firstOrNull?.stoneId;
              context.push(stoneId != null ? '/quotes/new?stoneId=$stoneId' : '/quotes/new');
            },
          ),
        ],
      ),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load results: $e', style: TextStyle(color: palette.textSecondary)),
          ),
        ),
        data: (jobs) {
          if (jobs.isEmpty) {
            return Center(
              child: Text('No variants yet — this can take a few seconds.', style: TextStyle(color: palette.textSecondary)),
            );
          }
          if (_fullscreenVariant != null) {
            final job = jobs.where((j) => j.variantIndex == _fullscreenVariant).firstOrNull;
            if (job != null) {
              return _FullscreenViewer(
                job: job,
                allJobs: jobs,
                onClose: () => setState(() => _fullscreenVariant = null),
                onSelectVariant: (i) => setState(() => _fullscreenVariant = i),
              );
            }
          }
          return _VariantGrid(
            jobs: jobs,
            onTapVariant: (i) => setState(() => _fullscreenVariant = i),
          );
        },
      ),
    );
  }
}

class _VariantGrid extends StatelessWidget {
  final List<AIJob> jobs;
  final void Function(int variantIndex) onTapVariant;

  const _VariantGrid({required this.jobs, required this.onTapVariant});

  @override
  Widget build(BuildContext context) {
    // Always render 4 slots, even if some jobs haven't arrived yet — the
    // batch insert is 4 parallel writes, so a slot can briefly be empty.
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        final job = jobs.where((j) => j.variantIndex == index).firstOrNull;
        return _VariantTile(
          variantIndex: index,
          job: job,
          onTap: job != null && job.isSuccessful ? () => onTapVariant(index) : null,
        );
      },
    );
  }
}

class _VariantTile extends StatelessWidget {
  final int variantIndex;
  final AIJob? job;
  final VoidCallback? onTap;

  const _VariantTile({required this.variantIndex, required this.job, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Colors.grey.shade900,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (job != null && job!.isSuccessful)
                Image.network(
                  job!.resultImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _TileError(message: 'Image failed to load'),
                )
              else if (job == null || job!.isActive)
                const _TileLoading()
              else if (job!.status == 'failed')
                _TileError(message: job!.errorMessage ?? 'Generation failed')
              else
                const _TileError(message: 'Unavailable'),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Variant ${variantIndex + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileLoading extends StatelessWidget {
  const _TileLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70),
      ),
    );
  }
}

class _TileError extends StatelessWidget {
  final String message;
  const _TileError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 22),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenViewer extends ConsumerStatefulWidget {
  final AIJob job;
  final List<AIJob> allJobs;
  final VoidCallback onClose;
  final void Function(int variantIndex) onSelectVariant;

  const _FullscreenViewer({
    required this.job,
    required this.allJobs,
    required this.onClose,
    required this.onSelectVariant,
  });

  @override
  ConsumerState<_FullscreenViewer> createState() => _FullscreenViewerState();
}

class _FullscreenViewerState extends ConsumerState<_FullscreenViewer> {
  bool _isSaving = false;
  bool _isDownloading = false;
  bool _isRegenerating = false;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    try {
      await ref.read(userRepositoryProvider).saveDesign(
            stoneId: widget.job.stoneId,
            stoneName: widget.job.stoneName ?? 'AI Visualization',
            roomImageUrl: widget.job.inputImageUrl,
            generatedImageUrl: widget.job.resultImageUrl!,
            color: widget.job.color,
            finish: widget.job.finish,
            notes: 'AI Studio variant ${widget.job.variantIndex + 1}',
          );
      if (!mounted) return;
      showSuccessSnackbar(context, 'Saved to your Saved Designs');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(context, e, customMessage: 'Could not save this design');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _download() async {
    setState(() => _isDownloading = true);
    HapticFeedback.mediumImpact();
    try {
      final uri = Uri.parse(widget.job.resultImageUrl!);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('Could not open image');
      if (!mounted) return;
      showSuccessSnackbar(context, 'Opening image — save it from there');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(context, e, customMessage: 'Could not download this image');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _share() async {
    HapticFeedback.lightImpact();
    try {
      await Share.share(
        'Grazia Stones AI Studio — ${widget.job.stoneName} (${widget.job.finish ?? 'Natural'} finish)\n${widget.job.resultImageUrl}',
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(context, e, customMessage: 'Could not share this design');
    }
  }

  Future<void> _regenerate() async {
    setState(() => _isRegenerating = true);
    HapticFeedback.mediumImpact();
    try {
      await ref.read(aiJobListProvider.notifier).retryJob(widget.job.id);
      if (!mounted) return;
      showSuccessSnackbar(context, 'Regenerating variant ${widget.job.variantIndex + 1}...');
      widget.onClose();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(context, e, customMessage: 'Could not regenerate');
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                  ),
                  Expanded(
                    child: Text(
                      '${job.stoneName ?? 'Concept'} · Variant ${job.variantIndex + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Compare strip — swipe between the 4 variants without leaving fullscreen.
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: widget.allJobs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final j = widget.allJobs[i];
                  final selected = j.variantIndex == job.variantIndex;
                  return GestureDetector(
                    onTap: j.isSuccessful ? () => widget.onSelectVariant(j.variantIndex) : null,
                    child: Container(
                      width: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selected ? Colors.amber : Colors.white24, width: selected ? 2 : 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: j.isSuccessful
                          ? Image.network(j.resultImageUrl!, fit: BoxFit.cover)
                          : Container(color: Colors.grey.shade800),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: job.isSuccessful
                      ? Image.network(job.resultImageUrl!, fit: BoxFit.contain)
                      : const Text('Image unavailable', style: TextStyle(color: Colors.white54)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _ActionButton(
                    icon: Icons.favorite_border,
                    label: 'Save',
                    loading: _isSaving,
                    onPressed: job.isSuccessful ? _save : null,
                  ),
                  _ActionButton(
                    icon: Icons.download_outlined,
                    label: 'Download',
                    loading: _isDownloading,
                    onPressed: job.isSuccessful ? _download : null,
                  ),
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onPressed: job.isSuccessful ? _share : null,
                  ),
                  _ActionButton(
                    icon: Icons.refresh,
                    label: 'Regenerate',
                    loading: _isRegenerating,
                    onPressed: _regenerate,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.loading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: IconButton(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
              )
            : Icon(icon, color: onPressed == null ? Colors.white24 : Colors.white),
        tooltip: label,
      ),
    );
  }
}
