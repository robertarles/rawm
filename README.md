# rawm

**rawm** is a native macOS app that combines window management, clipboard history, and an skhd-style hotkey system into a single tool.

It is currently intended for my personal use, scratching a particular itch. If you try to clone and build, you may run in to some friction (e.g. XCode project "team" config, etc)

Otherwise, `make install` should build and install a local working copy for you.

## Attribution

rawm is built on top of two open-source projects, each are excellent solutions on their own:

- [Rectangle](https://github.com/rxhanson/Rectangle) by Ryan Hanson — window snapping and keyboard-driven window management, itself based on Spectacle. Licensed MIT.
- [Maccy](https://github.com/p0deje/Maccy) by p0deje — lightweight clipboard history manager. Licensed MIT.

See LICENSE for details.

## System Requirements

macOS 10.15 or later.

## Features

- Window snapping and keyboard shortcuts (from Rectangle)
- Clipboard history manager (from Maccy)
- skhd-style configurable hotkey engine (coming soon)

## How to use it

Drag a window to the edge of the screen to snap it, or use keyboard shortcuts to resize and position windows. Access clipboard history via the menu bar icon.

See the [rawm repository](https://github.com/robertarles/rawm) for documentation and the full list of supported actions.

## Building from source

Use the Makefile:

```
make build      — Release build
make install    — Build + install to /Applications
make reinstall  — Uninstall then install fresh
make run        — Debug build and launch without installing
make test       — Run test suite
make clean      — Clean build artifacts
make open       — Open project in Xcode
```

## Accessibility Permission

rawm requires Accessibility permission to control window positions. On first launch, macOS will prompt you to grant this permission in System Settings > Privacy & Security > Accessibility.

## License

MIT License. See LICENSE for details.
