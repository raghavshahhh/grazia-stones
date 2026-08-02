# Grazia Stones — Full UI Overhaul Plan

## Problems Found
1. **Dual bottom nav** — `GraziaBottomNav` (HomeScreen) + `ScaffoldWithNavBar` (GoRouter) conflict
2. **Stone detail** — All `AppColors`, shows `$` not `₹`, no bulk booking, no real images, no AR/camera button
3. **Dual navigation** — `Navigator.pushNamed` + GoRouter = broken routing
4. **No swipe** — HomeScreen can't swipe between tabs
5. **HomeScreen owns tab state** — Should be in GoRouter ShellRoute

## Plan

### Phase 1: Apple-Style Bottom Nav + Fix Navigation (router.dart + grazia_bottom_nav.dart)

**Delete** `ScaffoldWithNavBar` from router.dart. **Replace** GraziaBottomNav with Apple-style version.

**Files:**
- `lib/config/router.dart` — Remove ScaffoldWithNavBar, use GraziaBottomNav in ShellRoute
- `lib/shared/widgets/grazia_bottom_nav.dart` — Full rewrite: Apple-style floating pill, rounded corners, swipeable, gold active indicator
- `lib/features/home/presentation/home_screen.dart` — Remove bottom nav, just show content based on GoRouter

**Apple-style bottom nav spec:**
- Floating pill shape (not full-width)
- 28px border radius on pill
- BackdropFilter blur (sigma 20)
- Active tab: gold icon + gold pill background + subtle scale animation
- Center "Live AI" button: raised gold gradient circle with camera icon
- SafeArea padding bottom: 16px
- Tab swipe gesture (PageView)

### Phase 2: Stone Detail Screen Overhaul

**File:** `lib/features/stone_detail/presentation/stone_detail_screen.dart`

**Changes:**
- Migrate all `AppColors` → Grazia palette tokens (GLuxuryPalettes.gold, etc.)
- Fix `$` → `₹` for Indian pricing
- Add real stone image (NetworkImage from stone.imageUrl)
- Add "Book for Bulk" section with quantity input + bulk pricing tiers
- Add "View in AR" + "AI Visualize" as hero buttons at bottom
- Add image gallery/dots indicator in SliverAppBar
- Add specs as premium glass cards instead of plain containers
- Add "Add to Wishlist" functionality
- Add reviews section (mock data)

### Phase 3: Wire Up All Navigation

**Files:**
- `lib/features/home/presentation/widgets/home_trending_grid.dart` — `Navigator.pushNamed` → `context.push('/stones/${s.id}')`
- `lib/features/home/presentation/widgets/home_collection_strip.dart` — Same fix
- `lib/features/search/presentation/search_screen.dart` — Same fix
- `lib/features/collections/presentation/collection_detail_screen.dart` — Same fix
- All other screens using `Navigator.pushNamed` → `context.push()`

### Phase 4: HomeScreen as GoRouter Shell

**File:** `lib/features/home/presentation/home_screen.dart`
- Remove bottom nav management, just show the home content
- Tab switching handled by GoRouter
- Add PageView for swipe between tabs (Home, Collections, Cart, Profile)

## Verification
- `flutter analyze` — 0 errors
- `flutter run` — App launches, all 5 tabs work
- Click stone → detail opens with ₹ pricing, bulk booking, AR button
- Bottom nav: Apple-style pill, swipeable, gold active state
- All navigation works via GoRouter
