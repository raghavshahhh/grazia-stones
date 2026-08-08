import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stone.dart';
import '../models/collection.dart';
import '../models/dealer.dart';
import '../repositories/stone_repository.dart';
import '../repositories/dealer_repository.dart';

/// Provides a single StoneRepository instance.
final stoneRepositoryProvider = Provider<StoneRepository>((_) => StoneRepository());
final dealerRepositoryProvider = Provider<DealerRepository>((_) => DealerRepository());

/// Fetches all active stones from Supabase.
final allStonesProvider = FutureProvider<List<Stone>>((ref) async {
  final repo = ref.watch(stoneRepositoryProvider);
  return repo.getStones(limit: 50);
});

/// Fetches all active collections.
final allCollectionsProvider = FutureProvider<List<Collection>>((ref) async {
  final repo = ref.watch(stoneRepositoryProvider);
  return repo.getCollections();
});

/// Fetches all active dealers.
final allDealersProvider = FutureProvider<List<Dealer>>((ref) async {
  final repo = ref.watch(dealerRepositoryProvider);
  return repo.getDealers();
});

/// Fetches a single stone by ID.
final stoneByIdProvider = FutureProvider.family<Stone?, String>((ref, id) async {
  final repo = ref.watch(stoneRepositoryProvider);
  return repo.getStoneById(id);
});
