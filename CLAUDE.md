# Tally

A notepad that calculates: a Soulver-style calculator for macOS. Part of
SPIIIRA Apps, Jonas's collection of Mac apps.

## Working with Jonas

- Jonas is not a programmer. Use plain language and give exact steps.
- No emojis.
- Ask before doing anything beyond the task.

## Building

- No Xcode project. `zsh build.sh` compiles `Sources/` with `swiftc` into
  `build/Tally.app` and installs it in /Applications.
- The engine tests run without building the app; the command is under Building
  in README.md.
- Cloud sessions can't build or run Mac apps. Say so instead of claiming a change
  works; Jonas tests it on his Mac.

## Housekeeping

- Keep README.md current when behavior changes.
- Claude sessions can push commits but can't delete branches or push tags.
- Web tools belong in jonasspira/jonasspira.github.io, not here.
