<p align="center">
  <img src="docs/icon.png" width="128" alt="Hueful icon">
</p>

<h1 align="center">Hueful</h1>

<p align="center">
  A color palette generator for iPhone, iPad and Mac, in the spirit of <a href="https://coolors.co">Coolors</a>.<br>
  One multiplatform SwiftUI app with a Liquid Glass interface, built with <a href="https://github.com/yonaskolb/XcodeGen">XcodeGen</a>.
</p>

<p align="center">
  <img src="docs/screenshot.png" width="520" alt="Hueful on Mac: a five-color palette in full-height columns, with the inspector showing the values, editor and tints of the selected color">
  <img src="docs/screenshot-ios.png" width="148" alt="Hueful on iPhone: five color bands with their HEX codes and names, one of them locked, and the Generate button above the tab bar">
</p>

## Features

- **Generate palettes**: press Generate (Space or ⌘G on Mac) for a new palette of harmonious colors. Lock the colors you like and only the others change.
- **Harmony rules**: Automatic picks colors freely by taste; Analogous, Monochromatic, Complementary, Split Complementary, Triadic and Square follow the color wheel.
- **Edit the palette**: from 2 to 10 colors. Add Color adds one that fits the others; remove a color with a swipe on iPhone or the × that appears on hover on Mac; drag colors to reorder them.
- **Undo and redo**: generating, adding, removing, moving and loading can be undone, with the Undo button on iPhone and ⌘Z / ⇧⌘Z on Mac.
- **Color details**: tap or click a color for its name, its HEX, RGB, HSL, HSB and CMYK values with a copy button each, a color picker and a HEX field to change it, and nine tints and shades to pick from. On Mac they open in the inspector.
- **Colors from a photo**: Colors from Photo… (iPhone, from the photo library) or Colors from Image… (Mac, ⌘O, from a file) replaces the palette with the main colors of the picture.
- **Library**: Save Palette… (⌘S on Mac) keeps a palette with a name. Open, rename, share or delete saved palettes in Library.
- **Share**: Share Image (a PNG of the palette), Share HEX Codes, or Share Coolors Link to open the same palette on coolors.co. Copy HEX Codes (⇧⌘C on Mac) puts them on the clipboard.
- **Contrast**: every pair of colors in the current palette, rated for text readability and sorted from most readable. Show Readable Pairs Only hides the rest; open a pair to preview a heading, body text, small print and icons, and Swap Colors.
  - Excellent: 7:1 or more (WCAG AAA), readable for any text.
  - Good: 4.5:1 (WCAG AA), fine for body text.
  - Headings Only: 3:1 (WCAG AA for large text), for headings and icons.
  - Poor: below 3:1, not for text.
- **Native on each platform**: tabs on iPhone; a sidebar, inspector and Palette menu on Mac, with one palette per window.
- **English and Italian**: follows the system language, or the per-app language in Settings.

## Requirements

- iOS or iPadOS 26, or macOS 26, to run the app.
- Xcode 27 to build it (the project is built with Xcode 27.0 and the 27 SDKs).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), only to regenerate the Xcode project after changing [project.yml](project.yml):

  ```bash
  brew install xcodegen
  ```

## Installation

```bash
git clone https://gitlab.com/giuliomaffei90/hueful.git
cd hueful
xcodebuild -project Hueful.xcodeproj -scheme Hueful -destination 'platform=macOS' \
  -derivedDataPath build CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build
open build/Build/Products/Debug/Hueful.app
```

This builds the Mac app and signs it ad hoc, so it runs on your own Mac without an Apple developer account. The project names the author's development team, which is why the command clears `DEVELOPMENT_TEAM`.

To run it on an iPhone or iPad, open `Hueful.xcodeproj` in Xcode, choose your own team under Signing & Capabilities, pick the device and press Run. A free Apple account works; the device needs Developer Mode turned on (Settings → Privacy & Security), and an app signed this way stops opening after 7 days until you run it again from Xcode.

`Hueful.xcodeproj` is generated from [project.yml](project.yml). Change settings, targets or files there and run `xcodegen` to rebuild the project; to make your team permanent, set `DEVELOPMENT_TEAM` in that file. The tests run with:

```bash
xcodebuild -project Hueful.xcodeproj -scheme Hueful -destination 'platform=macOS' \
  -derivedDataPath build CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= test
```

## How it works

What happens when you press Generate:

1. The Generate button in [GeneratorView.swift](Hueful/GeneratorView.swift), the Space key there, or Palette → Generate in [HuefulApp.swift](Hueful/HuefulApp.swift) calls `generate()` on the window's [PaletteModel](Hueful/PaletteModel.swift).
2. `generate()` passes the palette to `Harmony.generate` in [Harmony.swift](Hueful/Harmony.swift), with each unlocked color replaced by `nil`.
3. `Harmony` builds 300 candidate palettes in OKLCH, a color space where equal steps look equal:
   - hues start from a locked color, if any, then walk around the wheel in small steps with at most one jump for an accent (Automatic), or follow the offsets of the chosen rule;
   - lightness is spread from dark to light, either as a gradient or shuffled;
   - one colorfulness "mood" is shared by the whole palette, and about a third of the time one color is a near-neutral;
   - out-of-gamut colors lose just enough chroma to fit in sRGB (`RGB(l:c:h:)` in [RGB.swift](Hueful/RGB.swift)).
4. Each candidate is scored: colors far apart from each other, a wide lightness range and even colorfulness score higher. One of the ten best is picked at random, so every press gives something different.
5. The model registers the change with the window's undo manager and replaces the colors; the view animates to the new palette. Each color's name is the closest of the CSS named colors, measured in CIE Lab ([ColorNames.swift](Hueful/ColorNames.swift)).

The other features use the same model:

- Colors from a photo: the image is read with ImageIO, shrunk to 48×48 pixels, and its pixels are grouped with k-means into as many colors as the palette has, most common first (`RGB.dominant` in [RGB.swift](Hueful/RGB.swift)).
- Contrast: the WCAG 2 relative luminance of each color gives the ratio of each pair ([ContrastView.swift](Hueful/ContrastView.swift)).
- Library: saved palettes are a SwiftData model holding the name, the HEX codes and the date ([PaletteModel.swift](Hueful/PaletteModel.swift), [LibraryView.swift](Hueful/LibraryView.swift)).

## Known limitations

- The generator is an original approximation of Coolors' results, not its algorithm, which is not public.
- Color names come from the 140 CSS named colors, so they are approximate: a dark green may be called "Dark Olive Green".
- Saved palettes stay on the device that saved them. There is no iCloud sync between iPhone, iPad and Mac.
- Changes made in the color details (color picker, HEX field, tints and shades) and locking a color can't be undone.
- On iPhone, Colors from Photo… picks from the photo library; it can't take a new picture with the camera.

## Legal note

Hueful is an independent project, not affiliated with or endorsed by Coolors. Share Coolors Link only builds a link to the public coolors.co palette page; Coolors is a trademark of its owners.
