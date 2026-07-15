# Aesthetic Camera — QA Testing Guide

Real-time GPU camera-filter MVP. Android-first, iOS-ready architecture.

## Setup
```bash
cd ~/Desktop/aesthetic_camera
flutter run           # on a physical Android device (camera needs real hardware)
```
A debug APK is also prebuilt at `build/app/outputs/flutter-apk/app-debug.apk`.

## Test checklist

### 1. Permissions
- [ ] First launch shows the camera permission prompt.
- [ ] **Grant** → live preview appears full screen.
- [ ] **Deny** → friendly error with a "Grant access" button that re-prompts.
- [ ] Deny permanently → button becomes "Open settings" and opens system settings.

### 2. Live preview
- [ ] Preview fills the whole screen (no letterboxing/black bars).
- [ ] Preview is smooth — target 60 FPS, no visible stutter.

### 3. Filters (carousel)
- [ ] Bottom carousel shows 4 chips: Original, Aesthetic, Vintage, Cinematic.
- [ ] Tapping a chip updates the preview **instantly**.
- [ ] Selected chip enlarges, gets a warm accent ring, and auto-centers.
- [ ] Each look is distinct:
  - **Original** — untouched feed.
  - **Aesthetic** — warm, faded blacks, low saturation, subtle grain + vignette.
  - **Vintage** — sepia-leaning, heavier fade + grain, strong vignette.
  - **Cinematic** — teal shadows / orange highlights, punchy contrast.
- [ ] Film grain visibly shimmers over time (except Original).

### 4. Capture
- [ ] Tapping the shutter shows a white flash + spinner.
- [ ] "Saved to gallery" snackbar appears.
- [ ] Open Gallery/Photos → **Aesthetic Camera** album contains the shot.
- [ ] The saved photo has the **selected filter baked in** (matches the preview).
- [ ] Double-tapping the shutter does not double-capture.

### 5. Lifecycle / stability
- [ ] Background the app, return → preview resumes cleanly (no crash/black screen).
- [ ] Rotate-lock: app stays portrait.
- [ ] Rapidly switch filters + capture → no crashes, no memory growth.

## Performance verification
Run with `flutter run --profile` and open DevTools → Performance overlay:
- [ ] Raster + UI threads stay under 16 ms/frame while switching filters.
- [ ] No repeated `CameraPreview` rebuilds (only the shader layer repaints).

## Known MVP scope notes
- No face tracking / AR / beauty filters (by design — color filters only).
- Captured photo is the full sensor frame; on-screen preview is cover-cropped,
  so framing may differ slightly at the edges (standard camera behavior).
- iOS is architecturally supported (Info.plist configured) but validated on
  Android first per the brief.
