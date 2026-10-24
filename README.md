# Power Couple

A cooperative weekly game for couples: log predefined chores, earn points,
complete quests and defeat a shared boss every week. Flutter app, iOS first,
Android-ready, Supabase backend.

## Running it

### Demo mode (no backend)

With no Supabase config the app runs fully on-device with two seeded partners
(Alex and Sam) and three weeks of history. Use **Playing as … ⇄** in the top
bar to switch partner.

```bash
flutter run            # iOS simulator / device
flutter run -d chrome  # quick look in a browser
```

### With Supabase

The project URL and publishable key live in `config/supabase.json`. The
publishable key is meant to ship in client apps; row-level security in the
schema is what protects the data.

1. In the Supabase SQL editor, run `supabase/migrations/0001_init.sql` once.
2. Auth → Providers → Email: enabled. For quick testing you can turn off
   "Confirm email"; with it on, users confirm by email before signing in.
3. Run:

```bash
flutter run --dart-define-from-file=config/supabase.json
```

### Web (GitHub Pages)

Every push to `main` runs `.github/workflows/deploy-web.yml`: tests, a
release web build with the repo name as base path, and a deploy to
`https://<user>.github.io/<repo>/`. On phones, "Add to Home Screen" installs
it full screen with the app icon.

To try the web build locally:

```bash
flutter run -d chrome --dart-define-from-file=config/supabase.json
```

### iOS prerequisites

Xcode with its license accepted (`sudo xcodebuild -license`), plus CocoaPods.
Check with `flutter doctor`.

## Architecture

```
lib/
  domain/   pure Dart: catalog, calendar (household timezone), bosses & quests,
            scoring engine. Fully unit-tested (test/engine_test.dart).
  data/     Backend interface + SupabaseBackend + DemoBackend
  state/    AppController (ChangeNotifier) exposed via AppScope
  ui/       screens
supabase/   schema, RLS policies and RPCs
```

**The database stores facts, the client derives everything else.** Supabase
holds only memberships and an append-only task log (undo is a soft flag).
Points, boss damage, quest progress, weekly outcomes, streaks and badges are
computed by `ScoringEngine` from the logs. Both partners run the same engine on
the same data, so they always agree. Backdating or undoing a log simply
recalculates the affected past week, with no stored state to migrate.

## Product rules implemented

| Rule | Behaviour |
|---|---|
| Points | Logger gets the task's fixed points; team gets the same. |
| Shared tasks | Logger chooses; points split, odd point to logger; team gets full value. Partner isn't asked to approve. |
| "Other" | User-named, 10 pts to person and team; **no** boss damage, **no** quest progress. |
| Boss | One per week, rotates for everyone. Damage = base points of catalog tasks. Quest bonuses don't damage. |
| Quests | 4 per week from a rotating pool; kid/pet quests only for households that have them. Bonus goes to team points only. |
| Week | Monday 00:00 – Sunday 23:59 in the household timezone. |
| Backdating | "Earlier…" picks any date and time back to the household's start. Logs count toward the week they happened in. |
| Past weeks | Stay open: backdating or undo recalculates boss outcome, quests, streak and badges. |
| Undo | Soft-delete; entry stays visible as "undone". Recalculates everything. |
| Leaderboard | Home screen ranks partners by points with share %. |
| Catalog | Includes childcare and pets (hidden unless enabled in settings). |

### Defaults chosen during build (not yet decided by product, easy to change)

- **Who can undo:** only the person who logged a task (enforced in the `undo_log` RPC).
- **Backdating floor:** no earlier than the day the household was created.
- **Daily caps** per task, per household (e.g. vacuum 1/day, dishes 3/day, Other 5/day): see `lib/domain/catalog.dart`.
- **Duplicate warning:** same task by anyone within 30 minutes → "Already logged?" confirm, not a block.
- **First week boss** health is prorated to the days remaining, so a mid-week start is winnable.
- **New tasks** added to round out categories: errand, batch meal prep, dust, mop, tidy, declutter, water plants, pay bills, book appointments, plus 7 childcare and 5 pet tasks. All point values are hypotheses.
- **Leaving a household** keeps your past logs in its history ("Former partner").

## Not built yet

- Push notifications and reminders (P1), including "a past week's boss is now defeated".
- Server-side enforcement of daily caps (client-side only today).
- Account deletion flow (GDPR); the schema already keeps history via `on delete set null`.
- Launch screen, real boss artwork.

## App icon

The logo is drawn in code (`lib/ui/logo.dart`) and used both in-app and as the
launcher icon. After changing it, regenerate the icons:

```bash
flutter test tool/render_logo_test.dart
dart run flutter_launcher_icons
```
- Offline queue: logging needs a connection in Supabase mode.
