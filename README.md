# Tally

> **Tally has moved.** It now lives in the [`Tally/` folder of jonasspira/mac-apps](https://github.com/jonasspira/mac-apps/tree/main/Tally), with the rest of Jonas's Mac apps. This repository is archived and read-only. The 1.0.0 download on this repository's releases page still works.

A notepad that calculates — a Soulver-style calculator for Mac, part of SPIIIRA Apps.

## Download & Install

1. Grab **Tally.zip** from the [latest release](https://github.com/jonasspira/Tally/releases/latest) and unzip it.
2. Drag **Tally.app** into your **Applications** folder.
3. First launch: macOS will warn that it can't verify the app (Tally is open
   source but not notarized with Apple, which requires a paid developer
   account). To open it anyway:
   - Open **System Settings → Privacy & Security**, scroll down, and click
     **Open Anyway** next to the Tally message, then confirm.
   - Or run this once in Terminal instead:
     `xattr -d com.apple.quarantine /Applications/Tally.app`

Requires macOS 14 (Sonoma) or later on Apple Silicon.

Type thoughts mixed with numbers; every line that contains math shows a live
answer in the teal column on the right. Words that aren't math are ignored, so
"rent is 1500 + 200 for parking" just answers 1,700.

## What it understands

| You type | You get |
|---|---|
| `2 + 3 * 4` | 14 |
| `15% of 490` | 73.5 |
| `490 + 15%` | 563.5 |
| `120 as a % of 480` | 25% |
| `rent = 1500` … `rent + 200` | 1,700 |
| `total` (on its own line) | sum of the block above |
| `5 km in miles` | 3.1069 miles |
| `3 kg + 500 g` | 3.5 kg |
| `$120 in sek` | live exchange rate |
| `72 f in c` | 22.2222 °C |
| `days until dec 25` | 176 days |
| `may 5 + 43 days` | Wed, Jun 17 2026 |
| `9:30 + 2h 45m` | 12:15 |
| `// anything` | comment, no answer |

- **Click an answer** to copy it — or, while editing a later line, to insert a
  live `lineN` reference that updates when that line changes.
- **Sheets** live in the sidebar and autosave to
  `~/Library/Application Support/Tally/Sheets` as plain text.
- Exchange rates come from the free [frankfurter.app](https://frankfurter.app)
  API (ECB data), cached on disk so currency math works offline too.

## Building

```
zsh build.sh
```

Compiles everything with `swiftc`, signs ad-hoc, and installs Tally.app to
/Applications. No Xcode project needed.

Engine tests: `swiftc -parse-as-library Sources/Engine/*.swift scripts/test_engine.swift -o build/tally_test && ./build/tally_test`
