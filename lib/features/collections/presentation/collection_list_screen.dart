import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/shared/theme/tokens.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/shared/widgets/grazia_app_bar.dart';

class CollectionListScreen extends StatelessWidget {
  const CollectionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final collections = MockDataService.collections;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: GraziaAppBar(
        title: 'COLLECTIONS',
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textSecondary, size: 20),
        ),
      ),
      body: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: GLuxurySpacing.paddingBase,
        itemCount: collections.length,
        separatorBuilder: (_, __) => GLuxurySpacing.gapSm,
        itemBuilder: (context, index) {
          final collection = collections[index];
          return _CollectionCard(collection: collection);
        },
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final dynamic collection;
  
  const _CollectionCard({required this.collection});

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/collections/${collection.id}');
        },
        borderRadius: BorderRadius.circular(GTokens.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(GTokens.radiusLg),
            border: Border.all(color: palette.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: palette.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(Icons.collections_outlined, color: palette.background, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.name,
                      style: GLuxuryTypography.h3.copyWith(
                        color: palette.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      collection.description,
                      style: GLuxuryTypography.bodySmall.copyWith(
                        color: palette.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${collection.stoneCount} Products',
                      style: GLuxuryTypography.labelSmall.copyWith(
                        color: palette.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.textTertiary, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
