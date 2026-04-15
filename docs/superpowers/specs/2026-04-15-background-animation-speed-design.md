# Background Animation Speed Control

## Problem

Users with high-refresh-rate monitors (360Hz) report background animations appearing too fast. Whether the root cause is perceptual or mechanical, there's no way for users to adjust animation speed. All background effects run at a fixed tick rate with hardcoded speeds.

## Decision

Approach D: Separate tick chain for background effects only.

Background effect updates move from the global 30ms tick to their own dedicated tick with a variable interval. Three presets exposed in the F1 Backgrounds menu.

### Alternatives considered

- **Tick divisor (skip ticks)**: Slow mode halves framerate, causing visible jerkiness. Fast mode requires calling Update() twice per tick which is a hack.
- **Speed multiplier in effects**: Requires modifying all 5 effect files, converting integer speeds to float, handling each effect's speed model differently.
- **Variable global tick rate**: Affects everything (borders, pulse, idle timer, ASCII effects) not just backgrounds.
- **Time-delta based updates**: Correct long-term solution but requires refactoring all effect Update() signatures and internals. Fire effect (cellular automaton) maps poorly to time-delta model.

## Scope

### In scope (background effects)

- Fire
- ASCII Rain
- Matrix
- Fireworks
- Aquarium

### Out of scope

- ASCII Effects (Typewriter, Print, Beams, Pour)
- Border animations
- Screensaver animations
- Ticker/roast text

## Design

### Speed presets

| Preset | Tick interval | Effective FPS | Description |
|--------|--------------|---------------|-------------|
| Slow   | 60ms         | ~16fps        | Half speed  |
| Normal | 30ms         | ~33fps        | Current behavior (default) |
| Fast   | 15ms         | ~66fps        | Double speed |

### New tick system

A new `bgTickMsg` message type and `doBgTick(speed string)` function. Structurally identical to the existing `tickMsg`/`doTick()` but with a variable interval derived from the speed setting.

```go
type bgTickMsg time.Time

func doBgTick(speed string) tea.Cmd {
    interval := 30 * time.Millisecond
    switch speed {
    case "slow":
        interval = 60 * time.Millisecond
    case "fast":
        interval = 15 * time.Millisecond
    }
    return tea.Tick(interval, func(t time.Time) tea.Msg {
        return bgTickMsg(t)
    })
}
```

### Tick handler changes

The existing `tickMsg` handler loses these 5 effect Update() calls:

- `m.fireEffect.Update(m.animationFrame)`
- `m.rainEffect.Update(m.animationFrame)`
- `m.matrixEffect.Update(m.animationFrame)`
- `m.fireworksEffect.Update(m.animationFrame)`
- `m.aquariumEffect.Update()`

They move to a new `bgTickMsg` handler that also increments its own frame counter and re-schedules with `doBgTick(m.animSpeed)`.

The `bgTickMsg` handler needs its own frame counter (`m.bgAnimationFrame`) since background effects that receive a frame number should get one that reflects their actual update frequency, not the global tick count.

The global `tickMsg` handler retains: `m.animationFrame++`, `m.pulseColor`, `m.borderFrame`, idle timer checks, screensaver logic, gslapper lazy init, and out-of-scope effect updates (print, beams, pour).

The `UpdatePalette()` calls for the 5 background effects move to the `bgTickMsg` handler alongside their `Update()` calls. They're currently paired in the same `if` blocks and should stay together for simplicity. Palette only changes on theme switch so the call frequency doesn't matter.

### Model changes

New fields on the `model` struct:

```go
animSpeed        string // "slow", "normal", "fast"
bgAnimationFrame int    // frame counter for background effects
```

Default: `animSpeed: "normal"` in `initialModel()`.

### Init changes

`Init()` adds `doBgTick(m.animSpeed)` to the `tea.Batch()` return. Two independent tick chains run from startup.

### Preferences cache

New field in `cache.UserPreferences`:

```go
AnimSpeed string `json:"anim_speed"`
```

Defaults to `"normal"` when empty or missing. No migration needed for existing prefs.json files. Loaded at startup in `initialModel()`, saved alongside other preferences when changed.

### Menu UI

The Backgrounds submenu gains a speed selector row at the bottom:

```
  [✓] Fire
  [ ] ASCII Rain
  [ ] Matrix
  [ ] Fireworks
  [ ] Aquarium

  Speed: [●] Slow  [ ] Normal  [ ] Fast
```

The speed row is a single menu item. `[●]` marks the active speed; `[ ]` marks inactive options.

#### Interaction

- **Up/Down**: Navigate to/from the speed row like any other menu item
- **Left/Right**: Move between Slow/Normal/Fast when on the speed row (no-op on other rows)
- **Enter**: Cycles speed forward (Slow -> Normal -> Fast -> Slow) for convenience
- **Esc**: Back to main menu (unchanged)

On speed change:
1. `m.animSpeed` updates
2. Preferences save to cache
3. Next `bgTickMsg` re-schedules with the new interval automatically

Left/right keys are currently unused in all menu modes, so there are no conflicts.

### Menu rendering

The speed row renders differently from checkbox rows. The `navigateToBackgroundsSubmenu()` function adds a 7th option to `m.menuOptions` (e.g., `"Speed: ..."`) that is rendered with the radio-button style. The menu renderer detects this row and formats it with the `[●]`/`[ ]` indicators based on `m.animSpeed`.

### Files changed

| File | Change |
|------|--------|
| `cmd/sysc-greet/main.go` | Add `bgTickMsg` type, `doBgTick()` func, `bgTickMsg` handler, model fields, Init change |
| `cmd/sysc-greet/menu.go` | Add speed row to `navigateToBackgroundsSubmenu()`, render speed selector |
| `cmd/sysc-greet/main.go` (key handling) | Handle left/right on speed row, enter cycles speed |
| `internal/cache/cache.go` | Add `AnimSpeed` to `UserPreferences` |

No changes to any animation effect files.
