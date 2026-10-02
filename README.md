# LockForge

Design your own lock screen: drag a clock, date, weather, steps, next calendar event and custom text onto your wallpaper, a colour or one of your photos, then show it whenever your screen wakes. Flutter + native Android.

## Run it
```
flutter pub get
flutter run
```

## Using it
1. **Gallery**: your saved themes, with real thumbnails. Tap **New theme** and pick a template (or a blank canvas). *Import* (top right) opens a `.lockforge.json` someone shared with you.
2. **Editor**: the canvas is your phone screen in miniature, at true proportions.
   - Add widgets from the bar at the bottom; **Background** switches between wallpaper, a colour or a photo, with a dim slider for legibility.
   - Drag widgets to move them. A pink guide appears when a widget snaps to the centre.
   - Tap a widget to style it: size, weight, colour, shadow, clock format, or the text itself. Tap empty space to deselect.
   - **Undo/redo** are in the top bar. Everything saves automatically.
   - ▶ shows a full-screen preview with your real weather, steps and calendar.
3. **Use as lock screen** (⋮ menu): allow notifications and "Display over other apps", then tap **Set as lock screen**. Your design appears every time the screen wakes; swipe up to continue to your normal unlock. *Show it now* previews the real thing without turning the screen off.

Edits to the active theme sync to the lock screen automatically. Weather, steps and calendar refresh each time you open the app, or when you tap *Refresh*.

## How the lock screen works (and its limits)
Android doesn't let apps replace the real keyguard without root. LockForge shows a full-screen activity over it the moment the screen turns on, the same mechanism alarm and call screens use. Your PIN, pattern or fingerprint still protects the phone. It's a themed layer, not a security bypass.

- The wallpaper option draws through a transparent window, so it always matches your current system wallpaper. Android 13+ won't let apps read the wallpaper image, so on those versions the *editor* shows a placeholder gradient; the real lock screen still shows your wallpaper.
- The foreground service shows a small "lock screen is on" notification; Android requires it.
- Custom font families: add `.ttf` files to `assets/fonts/` and register them in `pubspec.yaml`.

## Home-screen widget
Long-press the home screen → Widgets → LockForge for a live clock, your next event and the weather.
