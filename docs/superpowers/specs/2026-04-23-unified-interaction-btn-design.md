# Unified InteractionBtn Design

## Goal

Unify the visual style of like/comment/share/bookmark buttons across all content types (posts, articles, feeds) using the post detail screen's `_InteractionBtn` as the standard. Each content type keeps its existing set of buttons — no features added or removed.

## Current State

| Page | Like | Comment | Share | Bookmark | Style |
|------|------|---------|-------|----------|-------|
| Post detail | Material Icon | Material Icon | Material Icon | None | Icon+number, 13px |
| Article detail | Emoji ❤️/🤍 | Emoji 💬 | Emoji ↗️ | Emoji 🔖 | Emoji+text, 11px |
| Post feed card | Emoji ❤️/🤍 | Emoji 💬 | Emoji ↗️ | None | Emoji+text, 11px |
| Activity feed card | Emoji ❤️/🤍 | Emoji 💬 | Emoji ↗️ | None | Emoji+text, 11px |
| Article feed card | Emoji ❤️/🤍 | None | Emoji ↗️ | Emoji 🔖 | Emoji+text, 11px |

## Design

### New Public Component

**File:** `lib/widgets/interaction_btn.dart`

Extract post detail's private `_InteractionBtn` into a public `InteractionBtn` widget with the same API:

- **Parameters:** `IconData icon`, `String label`, `Color color`
- **Layout:** `Row(mainAxisSize: min)` → `Icon(size: 18)` + `SizedBox(width: 5)` + `Text(fontSize: 13)`

### Icon Mapping

| Function | Inactive | Active | Active Color |
|----------|----------|--------|-------------|
| Like | `Icons.favorite_border` | `Icons.favorite` | `t.danger` |
| Comment | `Icons.chat_bubble_outline` | — | — |
| Share | `Icons.share_outlined` | — | — |
| Bookmark | `Icons.bookmark_border` | `Icons.bookmark` | `t.danger` |
| View count | `Icons.visibility_outlined` | — | — |

Default color for all inactive states: `t.inkSub`.

### Spacing

- Detail pages: `SizedBox(width: 28)` between buttons
- Feed cards: `SizedBox(width: 18)` between buttons (tighter space)

### File Changes

| File | Change |
|------|--------|
| `lib/widgets/interaction_btn.dart` | **New file.** Public `InteractionBtn` widget. |
| `lib/features/post/post_detail_screen.dart` | Delete private `_InteractionBtn`. Import and use public `InteractionBtn`. |
| `lib/features/article/article_detail_screen.dart` | Replace emoji-based buttons with `InteractionBtn`. Apply icon mapping. Keep existing view count, comment, like, bookmark, share buttons. |
| `lib/features/home/cards/post_feed_card.dart` | Replace emoji buttons with `InteractionBtn`. Keep like, comment, share. |
| `lib/features/home/cards/activity_feed_card.dart` | Replace emoji buttons with `InteractionBtn`. Keep like, comment, share. |
| `lib/features/home/cards/article_feed_card.dart` | Replace emoji buttons with `InteractionBtn`. Keep like, bookmark, share. |

### Not Changed

- `lib/features/pickup/pickup_detail_screen.dart` — uses `_CircleBtn` overlay on images, different UX context.
- `lib/features/home/cards/event_feed_card.dart` — no interaction buttons exist.
- `lib/features/home/cards/pickup_feed_card.dart` — no interaction buttons exist.

## Interaction Logic

No changes to interaction logic. Each page keeps its existing:
- `GestureDetector` wrappers and `onTap` callbacks
- Login checks (`isSignedIn` guard + SnackBar)
- Riverpod providers (`likedPostIdsProvider`, `likedArticleIdsProvider`, `favoriteArticleIdsProvider`)
- Repository calls (`likesRepoProvider.toggle()`, `favoritesRepoProvider.toggle()`)
