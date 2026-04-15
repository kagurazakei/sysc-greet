# Background Animation Speed Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users control background animation speed (Slow/Normal/Fast) via the F1 Backgrounds menu, using a dedicated tick chain that only affects background effects.

**Architecture:** A second `tea.Tick` chain (`bgTickMsg`) drives the 5 background effects at a variable interval (60ms/30ms/15ms). The global tick stays at 30ms for everything else. Speed selection persists in the preferences cache.

**Tech Stack:** Go, Bubble Tea v2 (beta), lipgloss v2

**Spec:** `docs/superpowers/specs/2026-04-15-background-animation-speed-design.md`

---

### Task 1: Add AnimSpeed to preferences cache

**Files:**
- Modify: `internal/cache/cache.go:67-75`

- [ ] **Step 1: Add AnimSpeed field to UserPreferences**

In `internal/cache/cache.go`, add the `AnimSpeed` field to the `UserPreferences` struct:

```go
type UserPreferences struct {
	Theme       string `json:"theme"`
	Background  string `json:"background"`
	Wallpaper   string `json:"wallpaper"`
	BorderStyle string `json:"border_style"`
	Session     string `json:"session"`
	Username    string `json:"username"`
	ASCIIIndex  int    `json:"ascii_index"`
	AnimSpeed   string `json:"anim_speed"`
}
```

No changes to `SavePreferences` or `LoadPreferences` — Go's JSON unmarshalling handles missing fields by zero-valuing them (empty string), which we treat as "normal" at the call site.

- [ ] **Step 2: Build to verify no compile errors**

Run: `make build`
Expected: `Binary built successfully`

- [ ] **Step 3: Commit**

```bash
git add internal/cache/cache.go
git commit -m "cache: add AnimSpeed to user preferences"
```

---

### Task 2: Add bgTickMsg, doBgTick, and model fields

**Files:**
- Modify: `cmd/sysc-greet/main.go:357-408` (model struct, message types, tick functions)

- [ ] **Step 1: Add model fields**

In the model struct (around line 358), add after `borderFrame int`:

```go
	animSpeed        string // "slow", "normal", "fast"
	bgAnimationFrame int    // frame counter for background effects
```

- [ ] **Step 2: Add bgTickMsg type and doBgTick function**

After the existing `doTick()` function (line 408), add:

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

- [ ] **Step 3: Set default animSpeed in initialModel**

In `initialModel()` (around line 555), add after `borderFrame: 0,`:

```go
		animSpeed:        "normal",
		bgAnimationFrame: 0,
```

- [ ] **Step 4: Load animSpeed from cached preferences**

In the preferences loading block (after line 624 where `m.asciiArtIndex` is loaded), add:

```go
			if prefs.AnimSpeed != "" {
				m.animSpeed = prefs.AnimSpeed
				logDebug("Loaded cached anim speed: %s", prefs.AnimSpeed)
			}
```

- [ ] **Step 5: Add doBgTick to Init**

In `Init()` (line 762), add `doBgTick(m.animSpeed)` to the batch:

```go
	return tea.Batch(
		textinput.Blink,
		m.spinner.Tick,
		doTick(),
		doBgTick(m.animSpeed),
		tea.RequestUniformKeyLayout,
	)
```

- [ ] **Step 6: Build to verify no compile errors**

Run: `make build`
Expected: `Binary built successfully`

- [ ] **Step 7: Commit**

```bash
git add cmd/sysc-greet/main.go
git commit -m "feat: add background tick chain and animSpeed model fields"
```

---

### Task 3: Split tick handlers — move background updates to bgTickMsg

**Files:**
- Modify: `cmd/sysc-greet/main.go:810-908` (tick handler)

This is the critical task. We move 5 effect Update() calls (with their paired UpdatePalette() calls and guard conditions) from `tickMsg` to a new `bgTickMsg` handler.

- [ ] **Step 1: Add bgTickMsg handler**

Add a new case in the `Update()` switch, right after the `tickMsg` case block (after the line `cmds = append(cmds, doTick())`). The new handler contains the 5 background effect blocks that were previously in `tickMsg`:

```go
	case bgTickMsg:
		m.bgAnimationFrame++

		if (m.enableFire || m.selectedBackground == "fire" || m.selectedBackground == "fire+rain") && m.fireEffect != nil {
			m.fireEffect.UpdatePalette(animations.GetFirePalette(m.currentTheme))
			m.fireEffect.Update(m.bgAnimationFrame)
		}

		if m.selectedBackground == "ascii-rain" && m.rainEffect != nil {
			m.rainEffect.UpdatePalette(animations.GetRainPalette(m.currentTheme))
			m.rainEffect.Update(m.bgAnimationFrame)
		}

		if m.selectedBackground == "matrix" && m.matrixEffect != nil {
			m.matrixEffect.UpdatePalette(animations.GetMatrixPalette(m.currentTheme))
			m.matrixEffect.Update(m.bgAnimationFrame)
		}

		if m.selectedBackground == "fireworks" && m.fireworksEffect != nil {
			m.fireworksEffect.UpdatePalette(animations.GetFireworksPalette(m.currentTheme))
			m.fireworksEffect.Update(m.bgAnimationFrame)
		}

		if m.selectedBackground == "aquarium" && m.aquariumEffect != nil {
			fishColors, waterColors, seaweedColors, bubbleColor, diverColor, boatColor, mermaidColor, _ := getThemeColorsForAquarium(m.currentTheme)
			m.aquariumEffect.UpdatePalette(fishColors, waterColors, seaweedColors, bubbleColor, diverColor, boatColor, mermaidColor)
			m.aquariumEffect.Update()
		}

		cmds = append(cmds, doBgTick(m.animSpeed))
```

- [ ] **Step 2: Remove the 5 background effect blocks from tickMsg handler**

Remove these blocks from the `tickMsg` case (currently lines 870-906). The blocks to remove are:

1. The `fireEffect` block (UpdatePalette + Update)
2. The `rainEffect` block (UpdatePalette + Update)
3. The `matrixEffect` block (UpdatePalette + Update)
4. The `fireworksEffect` block (UpdatePalette + Update)
5. The `aquariumEffect` block (UpdatePalette + Update)

Leave in place:
- `m.animationFrame++`, `m.pulseColor`, `m.borderFrame`
- Lazy init blocks (aquarium, gslapper)
- Screensaver logic
- Print effect (`m.printEffect.Tick(...)`)
- Beams effect (`m.beamsEffect.Update()`)
- Pour effect (`m.pourEffect.Update()`)
- `cmds = append(cmds, doTick())`

- [ ] **Step 3: Build to verify no compile errors**

Run: `make build`
Expected: `Binary built successfully`

- [ ] **Step 4: Run in test mode to verify animations still work**

Run: `kitty --start-as=fullscreen -e ./sysc-greet --test --debug`

Verify: Open F1 menu, select Fire background. Confirm fire animation renders and animates. Try Matrix, Rain, Fireworks. Confirm all still work. Press Ctrl+C to exit.

- [ ] **Step 5: Commit**

```bash
git add cmd/sysc-greet/main.go
git commit -m "feat: move background effects to dedicated tick chain"
```

---

### Task 4: Add speed selector to Backgrounds menu

**Files:**
- Modify: `cmd/sysc-greet/menu.go:41-62`

- [ ] **Step 1: Add speed row to navigateToBackgroundsSubmenu**

In `navigateToBackgroundsSubmenu()`, add the speed selector as the last menu option. After the aquarium checkbox line, add the speed row:

```go
func (m model) navigateToBackgroundsSubmenu() (tea.Model, tea.Cmd) {
	fireEnabled := m.selectedBackground == "fire" || m.enableFire
	rainEnabled := m.selectedBackground == "ascii-rain"
	matrixEnabled := m.selectedBackground == "matrix"
	fireworksEnabled := m.selectedBackground == "fireworks"
	aquariumEnabled := m.selectedBackground == "aquarium"

	m.menuOptions = []string{
		"← Back",
		formatCheckbox("Fire", fireEnabled),
		formatCheckbox("ASCII Rain", rainEnabled),
		formatCheckbox("Matrix", matrixEnabled),
		formatCheckbox("Fireworks", fireworksEnabled),
		formatCheckbox("Aquarium", aquariumEnabled),
		formatSpeedSelector(m.animSpeed),
	}
	m.mode = ModeBackgroundsSubmenu
	m.menuIndex = 0
	return m, nil
}
```

- [ ] **Step 2: Add formatSpeedSelector function**

Add this function in `menu.go` after `formatCheckbox`:

```go
// formatSpeedSelector returns the speed selector row with radio-button style indicators
func formatSpeedSelector(speed string) string {
	slow := "[ ]"
	normal := "[ ]"
	fast := "[ ]"
	switch speed {
	case "slow":
		slow = "[●]"
	case "fast":
		fast = "[●]"
	default:
		normal = "[●]"
	}
	return "Speed: " + slow + " Slow  " + normal + " Normal  " + fast + " Fast"
}
```

- [ ] **Step 3: Build to verify no compile errors**

Run: `make build`
Expected: `Binary built successfully`

- [ ] **Step 4: Commit**

```bash
git add cmd/sysc-greet/menu.go
git commit -m "feat: add speed selector row to backgrounds menu"
```

---

### Task 5: Handle speed selection input (Enter, Left, Right)

**Files:**
- Modify: `cmd/sysc-greet/main.go` (key handling in ModeBackgroundsSubmenu)

- [ ] **Step 1: Add speed cycling helper function**

Add this near `doBgTick()` in main.go:

```go
// cycleAnimSpeed cycles to the next speed preset
func cycleAnimSpeed(current string) string {
	switch current {
	case "slow":
		return "normal"
	case "normal":
		return "fast"
	case "fast":
		return "slow"
	default:
		return "normal"
	}
}
```

- [ ] **Step 2: Handle Enter on speed row**

In the `ModeBackgroundsSubmenu` case of the Enter key handler (around line 1705), the existing code strips checkbox prefixes and switches on `optionName`. The speed row starts with `"Speed: "` not `"[✓] "` or `"[ ] "`, so after the prefix stripping it will have `optionName = "Speed: ..."` which won't match any existing case.

Add a check at the top of the `ModeBackgroundsSubmenu` case, before the existing optionName stripping:

```go
			case ModeBackgroundsSubmenu:
				// Handle speed selector row
				if strings.HasPrefix(selectedOption, "Speed: ") {
					m.animSpeed = cycleAnimSpeed(m.animSpeed)
					if !m.config.TestMode {
						sessionName := ""
						if m.selectedSession != nil {
							sessionName = m.selectedSession.Name
						}
						cache.SavePreferences(cache.UserPreferences{
							Theme:       m.currentTheme,
							Background:  m.selectedBackground,
							Wallpaper:   m.selectedWallpaper,
							BorderStyle: m.selectedBorderStyle,
							Session:     sessionName,
							ASCIIIndex:  m.asciiArtIndex,
							AnimSpeed:   m.animSpeed,
						})
					}
					newModel, cmd := m.navigateToBackgroundsSubmenu()
					return newModel.(model), cmd
				}
				// CHANGED 2025-10-04 - Toggle backgrounds instead of replacing
				// Strip checkbox prefix to get actual option name
				optionName := strings.TrimPrefix(selectedOption, "[✓] ")
```

- [ ] **Step 3: Handle Left/Right keys on speed row**

In the key handling section, find where `"up"` and `"down"` are handled for menu navigation (around line 1306 for up, 1352 for down). Add left/right handlers nearby. Add this in the `handleKeyInput` function's key switch, as new cases:

```go
	case "left":
		if m.mode == ModeBackgroundsSubmenu && m.menuIndex == len(m.menuOptions)-1 {
			// On speed row — cycle backward
			switch m.animSpeed {
			case "normal":
				m.animSpeed = "slow"
			case "fast":
				m.animSpeed = "normal"
			case "slow":
				m.animSpeed = "fast"
			default:
				m.animSpeed = "slow"
			}
			if !m.config.TestMode {
				sessionName := ""
				if m.selectedSession != nil {
					sessionName = m.selectedSession.Name
				}
				cache.SavePreferences(cache.UserPreferences{
					Theme:       m.currentTheme,
					Background:  m.selectedBackground,
					Wallpaper:   m.selectedWallpaper,
					BorderStyle: m.selectedBorderStyle,
					Session:     sessionName,
					ASCIIIndex:  m.asciiArtIndex,
					AnimSpeed:   m.animSpeed,
				})
			}
			newModel, cmd := m.navigateToBackgroundsSubmenu()
			return newModel.(model), cmd
		}

	case "right":
		if m.mode == ModeBackgroundsSubmenu && m.menuIndex == len(m.menuOptions)-1 {
			// On speed row — cycle forward
			m.animSpeed = cycleAnimSpeed(m.animSpeed)
			if !m.config.TestMode {
				sessionName := ""
				if m.selectedSession != nil {
					sessionName = m.selectedSession.Name
				}
				cache.SavePreferences(cache.UserPreferences{
					Theme:       m.currentTheme,
					Background:  m.selectedBackground,
					Wallpaper:   m.selectedWallpaper,
					BorderStyle: m.selectedBorderStyle,
					Session:     sessionName,
					ASCIIIndex:  m.asciiArtIndex,
					AnimSpeed:   m.animSpeed,
				})
			}
			newModel, cmd := m.navigateToBackgroundsSubmenu()
			return newModel.(model), cmd
		}
```

- [ ] **Step 4: Update ALL existing SavePreferences calls in ModeBackgroundsSubmenu to include AnimSpeed**

Find the existing `cache.SavePreferences` call in the backgrounds handler (around line 1784) and add the `AnimSpeed` field:

```go
					cache.SavePreferences(cache.UserPreferences{
						Theme:       m.currentTheme,
						Background:  m.selectedBackground,
						Wallpaper:   m.selectedWallpaper,
						BorderStyle: m.selectedBorderStyle,
						Session:     sessionName,
						ASCIIIndex:  m.asciiArtIndex,
						AnimSpeed:   m.animSpeed,
					})
```

- [ ] **Step 5: Build to verify no compile errors**

Run: `make build`
Expected: `Binary built successfully`

- [ ] **Step 6: Test in kitty**

Run: `kitty --start-as=fullscreen -e ./sysc-greet --test --debug`

Verify:
1. Open F1 menu → Backgrounds
2. Speed row appears at bottom with `[●] Normal` selected
3. Navigate down to speed row
4. Press Right — changes to Fast, animation visibly speeds up
5. Press Right — changes to Slow, animation visibly slows down
6. Press Left — back to Fast
7. Press Enter — cycles forward
8. Exit and relaunch — speed setting persists

- [ ] **Step 7: Commit**

```bash
git add cmd/sysc-greet/main.go
git commit -m "feat: handle speed selection via Enter, Left, Right keys"
```

---

### Task 6: Add AnimSpeed to all remaining SavePreferences calls

**Files:**
- Modify: `cmd/sysc-greet/main.go` (all SavePreferences call sites)

Every `cache.SavePreferences()` call in the codebase needs the `AnimSpeed` field to avoid resetting it to empty string when saving from other menus (themes, borders, etc.).

- [ ] **Step 1: Find all SavePreferences calls**

Run: `grep -n "cache.SavePreferences" cmd/sysc-greet/main.go`

For each call that doesn't already have `AnimSpeed: m.animSpeed`, add it.

These are the call sites to update:
- Theme submenu save (around line 1636)
- Border submenu save (around line 1700)
- Successful login save (around line 1038)
- Any other call sites found by the grep

Add `AnimSpeed: m.animSpeed,` to each `cache.UserPreferences{}` literal.

- [ ] **Step 2: Build to verify**

Run: `make build`
Expected: `Binary built successfully`

- [ ] **Step 3: Commit**

```bash
git add cmd/sysc-greet/main.go
git commit -m "fix: include AnimSpeed in all SavePreferences calls"
```

---

### Task 7: Manual integration test

No files changed — this is a verification task.

- [ ] **Step 1: Full test in kitty**

Run: `kitty --start-as=fullscreen -e ./sysc-greet --test --debug`

Test matrix:
1. Set Fire background + Slow speed → fire animates at half speed
2. Set Fire background + Fast speed → fire animates at double speed
3. Switch to Matrix + Normal → matrix at normal speed
4. Switch to Rain + Slow → rain at half speed
5. Switch to Aquarium + Fast → aquarium at double speed
6. Switch to Fireworks + Normal → fireworks at normal speed
7. Open ASCII Effects → Beams → confirm beams are NOT affected by speed setting
8. Change theme while background is active → colors update correctly
9. Exit and relaunch → speed and background persist from cache
10. Change speed, change theme, exit, relaunch → both persist

- [ ] **Step 2: Check debug log for tick intervals**

Run: `grep -i "tick\|speed\|anim" ~/.cache/sysc-greet/debug.log | tail -20`

Verify the loaded anim speed log message appears and matches what was saved.

- [ ] **Step 3: Final commit if any fixes needed**

If any issues were found and fixed, commit them.
