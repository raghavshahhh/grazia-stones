# Grazia Stones — Production Roadmap

> Current State: 25-30/100 | Target: 90+/100  
> Strategy: WOW Demo First → Real Features → Production → Scale → White Label

---

## Phase 1: WOW Demo (Week 1-2)
**Goal:** Client sees the app and says "Wow, this is premium"
**Effort:** 2 weeks | **Risk:** Low | **Impact:** Client buy-in

### 1.1 Project Architecture Upgrade
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Upgrade `pubspec.yaml` — add riverpod, go_router, cached_network_image, shimmer, glassmorphism | pubspec.yaml | 1h | Low |
| Create `lib/app.dart` — Riverpod + GoRouter setup | app.dart | 2h | Low |
| Create `lib/config/router.dart` — GoRouter routes | router.dart | 2h | Low |
| Create `lib/core/di.dart` — Riverpod providers (service locator) | di.dart | 2h | Low |
| Migrate all Providers to Riverpod | cart_provider.dart, auth_provider.dart, quote_provider.dart | 4h | Medium |
| Migrate all screens from manual routing to GoRouter | 20+ screens | 6h | Medium |
| Verify every screen still works after migration | - | 2h | Low |

### 1.2 Premium Design System
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create `lib/shared/theme/tokens.dart` — spacing, radius, shadows, typography tokens | tokens.dart | 2h | Low |
| Create `lib/shared/theme/colors.dart` — 6 palette sets (Gold, Marble, Obsidian, Pearl, Rose Gold, Midnight) | colors.dart | 3h | Low |
| Create `lib/shared/theme/typography.dart` — 10-step scale with mobile/tablet/desktop | typography.dart | 2h | Low |
| Create `lib/shared/theme/gradients.dart` — 8+ luxury gradient definitions | gradients.dart | 1h | Low |
| Create `lib/shared/theme/shadows.dart` — 5 shadow levels with glow variants | shadows.dart | 1h | Low |
| Create `lib/shared/theme/spacing.dart` — 8-point grid system | spacing.dart | 1h | Low |
| Create `lib/shared/theme/borders.dart` — border styles and radius tokens | borders.dart | 1h | Low |

### 1.3 Premium Widget Library
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create `luxury_button.dart` — glass button, shimmer button, gradient button | widgets/ | 3h | Low |
| Create `luxury_card.dart` — glass morphism card, stone card with parallax | widgets/ | 3h | Low |
| Create `luxury_text_field.dart` — glass input, search bar | widgets/ | 2h | Low |
| Create `luxury_dialog.dart` — bottom sheet, modal, confirm dialog | widgets/ | 2h | Low |
| Create `luxury_shimmer.dart` — skeleton loading, shimmer effects | widgets/ | 2h | Low |
| Create `luxury_app_bar.dart` — transparent, glass, collapsing app bar | widgets/ | 2h | Low |
| Create `stone_card.dart` — premium stone card with hover/tap effects | widgets/ | 3h | Low |
| Create `collection_card.dart` — collection display card | widgets/ | 2h | Low |
| Create `dealer_card.dart` — dealer info card | widgets/ | 2h | Low |
| Create `price_badge.dart` — price display badge | widgets/ | 1h | Low |

### 1.4 Screen Transformations
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Transform `home_screen.dart` — hero parallax, staggered grid, shimmer loading, smooth scroll | home_screen.dart | 6h | Medium |
| Transform `collection_detail_screen.dart` — hero zoom, parallax scroll, animated filter | collection_detail_screen.dart | 5h | Medium |
| Transform `stone_detail_screen.dart` — full-screen gallery, AR preview, 3D rotate gesture | stone_detail_screen.dart | 5h | Medium |
| Transform `cart_screen.dart` — swipe-to-delete, animated total, glass summary card | cart_screen.dart | 3h | Medium |
| Transform `quote_request_screen.dart` — multi-step form with progress, glass cards | quote_request_screen.dart | 3h | Medium |
| Transform `search_screen.dart` — voice search, animated suggestions, filter chips | search_screen.dart | 3h | Medium |
| Transform `splash_screen.dart` — logo animation, particle effects | splash_screen.dart | 2h | Low |
| Transform `onboarding_screen.dart` — page animations, interactive elements | onboarding_screen.dart | 3h | Low |
| Transform `profile_screen.dart` — gradient header, glass cards | profile_screen.dart | 2h | Low |

### 1.5 Animations & Micro-interactions
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create `lib/shared/animations/fade_in.dart` — fade-in with slide-up | animations/ | 1h | Low |
| Create `lib/shared/animations/scale_in.dart` — scale-in bounce | animations/ | 1h | Low |
| Create `lib/shared/animations/shimmer_loading.dart` — shimmer skeleton | animations/ | 1h | Low |
| Create `lib/shared/animations/staggered_animation.dart` — staggered children | animations/ | 2h | Low |
| Create `lib/shared/animations/parallax_scroll.dart` — scroll parallax | animations/ | 2h | Low |
| Create `lib/shared/animations/hero_zoom.dart` — hero transition zoom | animations/ | 1h | Low |
| Create `lib/shared/animations/glass_blur.dart` — animated blur effect | animations/ | 1h | Low |
| Create `lib/shared/animations/particle_effects.dart` — decorative particles | animations/ | 2h | Low |
| Add page transitions to all screens | router.dart + screens | 3h | Low |

### 1.6 Content & Visual Polish
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Add 10 high-quality stone images (Pexels/Unsplash) | assets/images/ | 1h | Low |
| Add 3 collection cover images | assets/images/ | 30m | Low |
| Add luxury brand assets (logo, splash) | assets/ | 1h | Low |
| Create mock data with realistic pricing, descriptions | mock_data_service.dart | 2h | Low |
| Add dealer data with addresses, ratings | mock_data_service.dart | 1h | Low |
| Polish all empty states with CTAs | screens | 2h | Low |
| Add skeleton loading to all data screens | screens | 3h | Low |

### Phase 1 Verification
- [ ] App builds clean on Android, iOS, Web
- [ ] Every screen has premium animations
- [ ] No visual glitches on iPhone SE → iPad Pro
- [ ] All transitions smooth (60fps)
- [ ] Client demo ready — opens and "wows" within 5 seconds

---

## Phase 2: Real Features (Week 3-6)
**Goal:** Working backend, real data, real functionality
**Effort:** 4 weeks | **Risk:** Medium | **Impact:** Product viability

### 2.1 Backend Architecture
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create `backend/` — Node.js/Express or Python/FastAPI | backend/ | 8h | Medium |
| Design database schema (Supabase/PostgreSQL) | schema.sql | 6h | Medium |
| Create Supabase project and tables | Supabase | 4h | Medium |
| Set up auth (Supabase Auth — email/phone/Google) | backend | 4h | Medium |
| Create API routes: `/auth`, `/stones`, `/collections`, `/dealers`, `/cart`, `/orders`, `/quotes` | backend | 8h | Medium |
| Set up file storage (Supabase Storage — stone images) | backend | 2h | Low |
| Create seed script with real data | backend | 4h | Low |
| Deploy backend (Railway/Render) | backend | 2h | Low |

### 2.2 Repository Pattern
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create `lib/core/network/api_client.dart` — Dio setup with interceptors | api_client.dart | 3h | Medium |
| Create `lib/core/network/endpoints.dart` — API endpoint constants | endpoints.dart | 1h | Low |
| Create `lib/core/network/exceptions.dart` — typed API exceptions | exceptions.dart | 2h | Low |
| Create `lib/core/network/interceptors.dart` — auth, logging, retry | interceptors.dart | 2h | Medium |
| Create `lib/core/repositories/base_repository.dart` — generic CRUD | base_repository.dart | 3h | Medium |
| Create `lib/core/repositories/stone_repository.dart` | stone_repository.dart | 2h | Low |
| Create `lib/core/repositories/collection_repository.dart` | collection_repository.dart | 2h | Low |
| Create `lib/core/repositories/dealer_repository.dart` | dealer_repository.dart | 2h | Low |
| Create `lib/core/repositories/cart_repository.dart` | cart_repository.dart | 2h | Low |
| Create `lib/core/repositories/quote_repository.dart` | quote_repository.dart | 2h | Low |
| Create `lib/core/repositories/auth_repository.dart` | auth_repository.dart | 2h | Low |

### 2.3 Auth Flow
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create `lib/features/auth/presentation/login_screen.dart` — email/phone/Google | login_screen.dart | 4h | Medium |
| Create `lib/features/auth/presentation/signup_screen.dart` | signup_screen.dart | 3h | Low |
| Create `lib/features/auth/presentation/forgot_password_screen.dart` | forgot_password_screen.dart | 1h | Low |
| Create `lib/features/auth/presentation/otp_screen.dart` | otp_screen.dart | 2h | Low |
| Create `lib/features/auth/presentation/profile_setup_screen.dart` | profile_setup_screen.dart | 2h | Low |
| Create `lib/features/auth/providers/auth_provider.dart` — Riverpod | auth_provider.dart | 3h | Medium |
| Add auth guards to protected routes | router.dart | 2h | Medium |
| Store JWT securely (flutter_secure_storage) | auth_provider.dart | 1h | Medium |

### 2.4 Product Features
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create `lib/features/stones/data/stone_repository.dart` — API integration | stone_repository.dart | 3h | Medium |
| Create `lib/features/stones/presentation/stone_list_screen.dart` — paginated list | stone_list_screen.dart | 4h | Medium |
| Create `lib/features/stones/presentation/stone_detail_screen.dart` — full detail | stone_detail_screen.dart | 5h | Medium |
| Create `lib/features/collections/data/collection_repository.dart` | collection_repository.dart | 2h | Low |
| Create `lib/features/collections/presentation/collections_screen.dart` | collections_screen.dart | 3h | Low |
| Create `lib/features/collections/presentation/collection_detail_screen.dart` | collection_detail_screen.dart | 4h | Low |
| Create `lib/features/dealers/presentation/dealer_list_screen.dart` | dealer_list_screen.dart | 3h | Low |
| Create `lib/features/dealers/presentation/dealer_detail_screen.dart` | dealer_detail_screen.dart | 3h | Low |

### 2.5 E-commerce Features
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create `lib/features/cart/data/cart_repository.dart` — API sync | cart_repository.dart | 3h | Medium |
| Create `lib/features/cart/providers/cart_provider.dart` — Riverpod + API | cart_provider.dart | 4h | Medium |
| Create `lib/features/cart/presentation/cart_screen.dart` — full cart | cart_screen.dart | 4h | Medium |
| Create `lib/features/orders/data/order_repository.dart` | order_repository.dart | 2h | Low |
| Create `lib/features/orders/presentation/order_list_screen.dart` | order_list_screen.dart | 3h | Low |
| Create `lib/features/orders/presentation/order_detail_screen.dart` | order_detail_screen.dart | 3h | Low |
| Create `lib/features/orders/presentation/order_tracking_screen.dart` | order_tracking_screen.dart | 3h | Low |
| Create `lib/features/quotes/data/quote_repository.dart` | quote_repository.dart | 2h | Low |
| Create `lib/features/quotes/presentation/quote_request_screen.dart` | quote_request_screen.dart | 3h | Low |
| Create `lib/features/quotes/presentation/quote_list_screen.dart` | quote_list_screen.dart | 2h | Low |
| Create `lib/features/quotes/presentation/quote_detail_screen.dart` | quote_detail_screen.dart | 2h | Low |

### 2.6 Search & Filters
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create `lib/features/search/data/search_repository.dart` | search_repository.dart | 2h | Medium |
| Create `lib/features/search/presentation/search_screen.dart` — full search | search_screen.dart | 4h | Medium |
| Create `lib/features/search/presentation/filter_screen.dart` — advanced filters | filter_screen.dart | 3h | Medium |
| Create `lib/features/search/presentation/search_results_screen.dart` | search_results_screen.dart | 3h | Low |
| Implement search suggestions | search_screen.dart | 2h | Low |
| Implement search history | search_screen.dart | 1h | Low |

### 2.7 Notifications & Push
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Set up Firebase Cloud Messaging | firebase | 3h | Medium |
| Create notification handler | lib/ | 2h | Medium |
| Create notification list screen | screens | 3h | Low |
| Create notification preferences screen | screens | 2h | Low |
| Send push for order updates, new collections, promotions | backend | 3h | Medium |

### Phase 2 Verification
- [ ] Real auth works (signup, login, logout, forgot password)
- [ ] Real stone data loads from API
- [ ] Real cart syncs with backend
- [ ] Real quote requests are created
- [ ] Real dealer data loads
- [ ] Search works with filters
- [ ] Push notifications work
- [ ] App works offline (cached data)

---

## Phase 3: Production Polish (Week 7-10)
**Goal:** Store-ready, performant, tested, secure
**Effort:** 4 weeks | **Risk:** Medium | **Impact:** Market readiness

### 3.1 Performance Optimization
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Implement image caching (cached_network_image + custom cache) | multiple | 4h | Low |
| Implement lazy loading for lists | screens | 3h | Low |
| Add pagination (infinite scroll) | screens | 4h | Medium |
| Optimize bundle size (tree shaking, code splitting) | web | 3h | Low |
| Add image compression and WebP conversion | assets | 2h | Low |
| Implement database query optimization | backend | 4h | Medium |
| Add Redis caching for API responses | backend | 3h | Medium |
| Optimize Flutter build (remove unused imports, debug prints) | all files | 4h | Low |
| Add performance monitoring (Firebase Performance) | app | 2h | Low |
| Profile and fix jank frames | screens | 6h | Medium |

### 3.2 Error Handling & Resilience
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create `lib/core/errors/app_exception.dart` — typed exceptions | app_exception.dart | 3h | Low |
| Create `lib/core/errors/error_handler.dart` — global error handler | error_handler.dart | 3h | Low |
| Create `lib/core/widgets/error_widget.dart` — premium error UI | error_widget.dart | 2h | Low |
| Create `lib/core/widgets/empty_state.dart` — empty state with CTA | empty_state.dart | 2h | Low |
| Create `lib/core/widgets/loading_overlay.dart` — loading overlay | loading_overlay.dart | 1h | Low |
| Add retry logic to all API calls | repositories | 3h | Low |
| Add timeout handling | api_client.dart | 2h | Low |
| Add offline fallback (cached data) | repositories | 4h | Medium |
| Create `lib/core/network/connectivity.dart` — connectivity checker | connectivity.dart | 2h | Low |

### 3.3 State Management Cleanup
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Audit all Riverpod providers | providers | 3h | Low |
| Add `.autoDispose` to all screen-specific providers | providers | 2h | Low |
| Add loading states to all providers | providers | 3h | Low |
| Add error states to all providers | providers | 3h | Low |
| Add `ref.invalidate()` for cache invalidation | providers | 2h | Low |
| Test provider lifecycle (dispose on screen exit) | providers | 2h | Low |

### 3.4 Security Hardening
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Add certificate pinning | api_client.dart | 3h | Medium |
| Add request signing | api_client.dart | 2h | Medium |
| Obfuscate Flutter build | build | 2h | Low |
| Add jailbreak/root detection | app | 2h | Low |
| Add screenshot prevention on sensitive screens | screens | 2h | Low |
| Add biometric auth option | auth | 3h | Medium |
| Add session timeout | auth | 2h | Low |
| Add rate limiting on backend | backend | 2h | Low |
| Add input validation on backend | backend | 3h | Medium |
| Add CORS, CSP headers | backend | 2h | Low |

### 3.5 Analytics & Monitoring
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Set up Firebase Analytics | app | 3h | Low |
| Create analytics events for key actions | screens | 4h | Low |
| Set up Sentry for crash reporting | app | 3h | Low |
| Create custom error tracking | app | 2h | Low |
| Set up Firebase Crashlytics | app | 2h | Low |
| Add A/B testing infrastructure | app | 4h | Medium |
| Create analytics dashboard | admin | 6h | Medium |

### 3.6 Testing
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Set up test infrastructure (unit, widget, integration) | test/ | 3h | Low |
| Write unit tests for repositories | test/unit/ | 6h | Medium |
| Write unit tests for providers | test/unit/ | 4h | Low |
| Write unit tests for models | test/unit/ | 3h | Low |
| Write widget tests for key screens | test/widget/ | 8h | Medium |
| Write integration tests for critical flows | test/integration/ | 8h | High |
| Set up CI/CD pipeline (GitHub Actions) | .github/ | 4h | Medium |
| Add code coverage reporting | .github/ | 2h | Low |
| Achieve 80%+ test coverage | - | ongoing | Low |

### 3.7 Store Preparation
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create App Store screenshots (6.5", 5.5", iPad) | assets/ | 4h | Low |
| Create Play Store screenshots | assets/ | 2h | Low |
| Write App Store description | metadata | 2h | Low |
| Write Play Store description | metadata | 2h | Low |
| Create privacy policy | legal | 2h | Low |
| Create terms of service | legal | 2h | Low |
| Create app preview video | assets | 4h | Low |
| Set up Firebase App Distribution for beta | firebase | 2h | Low |
| Submit to TestFlight / Internal Testing | store | 2h | Low |
| Final QA pass | - | 8h | Medium |

### 3.8 Documentation
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Update README.md | README.md | 2h | Low |
| Create CONTRIBUTING.md | CONTRIBUTING.md | 1h | Low |
| Create API documentation | docs/ | 4h | Low |
| Create architecture diagram | docs/ | 2h | Low |
| Create deployment guide | docs/ | 2h | Low |
| Create white-label setup guide | docs/ | 3h | Low |

### Phase 3 Verification
- [ ] App passes 60fps profiling on mid-range Android
- [ ] Cold start < 2 seconds
- [ ] Image loading < 1 second (cached)
- [ ] Offline mode works (read-only)
- [ ] All tests pass
- [ ] No crashes in 24-hour soak test
- [ ] Security audit passed
- [ ] App Store submission ready
- [ ] Play Store submission ready

---

## Phase 4: Scale & Growth (Week 11-14)
**Goal:** Growth features, partnerships, market expansion
**Effort:** 4 weeks | **Risk:** Medium | **Impact:** Revenue growth

### 4.1 Growth Features
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create referral program (invite & earn) | backend + app | 6h | Medium |
| Create loyalty program (points, rewards) | backend + app | 8h | Medium |
| Create wish list feature | app | 3h | Low |
| Create price alert feature (notify when price drops) | app + backend | 4h | Medium |
| Create compare stones feature | app | 3h | Low |
| Create share stones feature (social sharing) | app | 2h | Low |
| Create AR room visualizer (real AR) | app | 12h | High |
| Create AI style recommender | app + backend | 8h | High |
| Create dealer locator with maps | app | 6h | Medium |
| Create in-app chat with dealers | app + backend | 8h | High |

### 4.2 Business Features
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create dealer dashboard (web) | web | 16h | High |
| Create dealer analytics | web | 8h | Medium |
| Create dealer inventory management | web | 8h | Medium |
| Create dealer order management | web | 6h | Medium |
| Create dealer quote management | web | 6h | Medium |
| Create dealer customer management | web | 4h | Medium |
| Create dealer marketing tools | web | 6h | Medium |

### 4.3 Content & Marketing
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create design inspiration gallery | app | 6h | Medium |
| Create project showcase (before/after) | app | 6h | Medium |
| Create style guide / lookbook | app | 4h | Low |
| Create installation guides | app | 4h | Low |
| Create maintenance guides | app | 4h | Low |
| Create blog / articles section | app | 6h | Medium |
| Create social media integration | app | 4h | Medium |
| Create email marketing integration | backend | 4h | Medium |

### 4.4 Internationalization
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Set up i18n infrastructure | app | 3h | Low |
| Create English translations | lib/ | 2h | Low |
| Create Hindi translations | lib/ | 3h | Low |
| Create Arabic translations (RTL) | lib/ | 4h | Medium |
| Create multi-currency support | app + backend | 6h | Medium |
| Create multi-language content | backend | 4h | Low |

### Phase 4 Verification
- [ ] Referral program tracks and rewards correctly
- [ ] Loyalty points calculate and redeem correctly
- [ ] AR room visualizer works on 80%+ devices
- [ ] Dealer dashboard fully functional
- [ ] All translations correct
- [ ] Multi-currency works

---

## Phase 5: White Label SaaS (Week 15-20)
**Goal:** Platform that can onboard any stone/tile brand in 1 day
**Effort:** 6 weeks | **Risk:** High | **Impact:** Scale to 100+ clients

### 5.1 Multi-Tenant Architecture
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Design multi-tenant database schema | backend | 8h | High |
| Implement tenant isolation (row-level security) | backend | 8h | High |
| Create tenant configuration system | backend | 6h | Medium |
| Create tenant onboarding API | backend | 6h | Medium |
| Create tenant admin dashboard | web | 12h | High |
| Create tenant branding system (logo, colors, fonts) | backend | 6h | Medium |
| Create tenant feature flags | backend | 4h | Medium |
| Create tenant billing (Stripe integration) | backend | 8h | High |

### 5.2 Theme Engine
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create dynamic theme system (JSON-based) | app | 8h | High |
| Create theme preview tool | web | 6h | Medium |
| Create theme marketplace | web | 8h | Medium |
| Create 5 pre-built themes (luxury, minimal, modern, classic, bold) | app | 10h | Medium |
| Create theme hot-reload (no app rebuild) | app | 6h | High |
| Create theme analytics (which themes work best) | backend | 4h | Medium |

### 5.3 Onboarding System
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create brand onboarding wizard | web | 8h | Medium |
| Create data import tool (CSV, API) | web + backend | 8h | Medium |
| Create image upload & processing pipeline | backend | 6h | Medium |
| Create SEO setup wizard | web | 4h | Low |
| Create domain mapping system | backend | 4h | Medium |
| Create SSL certificate automation | backend | 2h | Low |
| Create onboarding checklist | web | 3h | Low |

### 5.4 Analytics & Insights
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create tenant analytics dashboard | web | 12h | High |
| Create customer behavior analytics | backend | 8h | High |
| Create sales analytics | backend | 6h | Medium |
| Create marketing analytics | backend | 6h | Medium |
| Create inventory analytics | backend | 4h | Medium |
| Create automated reports (email) | backend | 4h | Medium |
| Create data export (CSV, PDF) | web | 4h | Low |

### 5.5 Platform Features
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create platform admin dashboard | web | 12h | High |
| Create tenant management (CRUD) | web + backend | 6h | Medium |
| Create billing management | web + backend | 6h | Medium |
| Create support ticket system | web + backend | 8h | Medium |
| Create knowledge base | web | 6h | Low |
| Create API rate limiting per tenant | backend | 3h | Low |
| Create tenant usage tracking | backend | 4h | Medium |
| Create SLA monitoring | backend | 4h | Medium |

### 5.6 Documentation & Support
| Task | Files | Effort | Risk |
|------|-------|--------|------|
| Create platform documentation | docs | 8h | Low |
| Create tenant onboarding guide | docs | 4h | Low |
| Create API reference | docs | 6h | Low |
| Create video tutorials | assets | 8h | Low |
| Create support chatbot | backend | 6h | Medium |
| Create community forum | web | 8h | Medium |

### Phase 5 Verification
- [ ] New brand can onboard in < 1 day
- [ ] Brand can customize theme without code changes
- [ ] Multi-tenant isolation verified (no data leaks)
- [ ] Billing works correctly
- [ ] Analytics accurate
- [ ] Platform handles 100+ tenants
- [ ] API rate limiting works
- [ ] Documentation complete

---

## Execution Timeline

```
Week 1-2:   Phase 1 — WOW Demo
Week 3-6:   Phase 2 — Real Features
Week 7-10:  Phase 3 — Production Polish
Week 11-14: Phase 4 — Scale & Growth
Week 15-20: Phase 5 — White Label SaaS
```

## Risk Mitigation

| Risk | Mitigation | Owner |
|------|-----------|-------|
| AR doesn't work on old devices | Graceful degradation + 2D fallback | Raghav |
| Backend takes too long | Use Supabase (skip custom backend) | Raghav |
| Client changes requirements | Phase-gated reviews after each phase | Raghav |
| App rejected by stores | Pre-submission QA + compliance check | Raghav |
| Performance issues on Android | Profile early, fix jank in Phase 3 | Raghav |
| Security breach | Security audit in Phase 3, pen testing | Raghav |
| Scope creep | Strict phase boundaries, no gold plating | Raghav |

## Success Metrics

| Metric | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 |
|--------|---------|---------|---------|---------|---------|
| Client Wow Factor | 10/10 | - | - | - | - |
| Working Features | 0% | 80% | 100% | 100% | 100% |
| Test Coverage | 0% | 20% | 80% | 80% | 80% |
| App Store Ready | No | No | Yes | Yes | Yes |
| Revenue | ₹0 | ₹0 | ₹0 | ₹50K/mo | ₹5L/mo |
| Clients | 1 (Grazia) | 1 | 1 | 5 | 50+ |
| Countries | 1 (India) | 1 | 1 | 3 | 10+ |

---

> **Next:** Execute Phase 1 — Start with architecture upgrade and design system
