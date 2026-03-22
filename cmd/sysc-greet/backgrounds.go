package main

import (
	"image/color"
)

// Background Effects - Extracted during Phase 5 refactoring
// This file contains background animation rendering (fire, matrix, rain, fireworks)
// IMPORTANT: These render functions are called from View() (value receiver).
// All state mutation (Update, Resize) must happen in Update() handlers, never here.

// applyBackgroundAnimation routes to the appropriate background effect based on selection
func (m model) applyBackgroundAnimation(content string) string {
	switch m.selectedBackground {
	case "fire": // Add fire effect rendering
		return m.addFireEffect(content)
	case "matrix":
		return m.addMatrixEffect(content)
	case "ascii-rain": // CHANGED 2025-10-08 - Add ascii rain effect
		return m.addAsciiRain(content)
	case "fireworks": // Add fireworks effect rendering
		return m.addFireworksEffect(content)
	case "aquarium":
		return m.addAquariumEffect(content)
	case "none":
		fallthrough
	default:
		return content
	}
}

// addFireEffect renders the fire background (render only, no state mutation)
func (m model) addFireEffect(content string) string {
	if m.fireEffect == nil {
		return content
	}
	return m.fireEffect.Render()
}

// addAsciiRain renders the ASCII rain background (render only, no state mutation)
func (m model) addAsciiRain(content string) string {
	if m.rainEffect == nil {
		return content
	}
	return m.rainEffect.Render()
}

// addMatrixEffect renders the Matrix-style background (render only, no state mutation)
func (m model) addMatrixEffect(content string) string {
	if m.matrixEffect == nil {
		return content
	}
	return m.matrixEffect.Render()
}

// addFireworksEffect renders the fireworks background (render only, no state mutation)
func (m model) addFireworksEffect(content string) string {
	if m.fireworksEffect == nil {
		return content
	}
	return m.fireworksEffect.Render()
}

// addAquariumEffect renders the aquarium background (render only, no state mutation)
func (m model) addAquariumEffect(content string) string {
	if m.aquariumEffect == nil {
		return content
	}
	return m.aquariumEffect.Render()
}

// getBackgroundColor returns the background color (always BgBase to prevent bleeding)
func (m model) getBackgroundColor() color.Color {
	// Always return BgBase to prevent bleeding
	return BgBase
}
