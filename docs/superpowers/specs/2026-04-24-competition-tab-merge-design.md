# Competition Tab Merge Design

## Summary

Merge the top-level "Bracket" (赛程) and "Standings" (积分榜) tabs into a single "Competition" (赛况) tab with an internal Segmented Control sub-toggle, reducing event detail tabs from 6 to 5.

## Motivation

6 horizontal tabs are crowded on mobile. Bracket and Standings both derive from match data and represent "competition progress" — they belong together conceptually.

## Design

### New file: `panels/competition_panel.dart`

- `CompetitionPanel(eventId: String)` — StatefulWidget
- Internal state `_sub`: `'bracket'` (default) or `'standings'`
- Top: Segmented Control with two segments using existing l10n keys `event_tab_bracket` and `event_tab_standings`
- Body: conditionally renders `BracketPanel` or `StandingsPanel` based on `_sub`
- Segmented Control style: pill-shaped container with `tokens.elev2` background, selected segment uses `tokens.accent` fill + `tokens.accentInk` text, unselected uses `tokens.inkSub` text, overall border radius `tokens.r2`

### Modified: `event_detail_screen.dart`

- Remove `('bracket', l.event_tab_bracket)` and `('standings', l.event_tab_standings)` from tabs list
- Add `('competition', l.event_tab_competition)` in their place (position index 2)
- Update switch: remove bracket/standings cases, add `'competition' => CompetitionPanel(eventId: event.id)`
- Change default `_tab` from `'bracket'` to `'competition'`
- Replace bracket_panel/standings_panel imports with competition_panel import

### L10n changes

- Add `event_tab_competition`: EN "Competition", ZH "赛况"
- Retain `event_tab_bracket` and `event_tab_standings` (reused inside Segmented Control)

### Final tab structure

```
Before (6): Overview | Teams | Bracket | Standings | Scorers | Chat
After  (5): Overview | Teams | Competition | Scorers | Chat
                                └─ [Bracket | Standings] ← Segmented Control
```

## Files changed

1. `lib/features/events/panels/competition_panel.dart` — NEW
2. `lib/features/events/event_detail_screen.dart` — MODIFIED
3. `lib/l10n/app_en.arb` — MODIFIED (add event_tab_competition)
4. `lib/l10n/app_zh.arb` — MODIFIED (add event_tab_competition)
