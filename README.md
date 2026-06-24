# rawm

**rawm** is a native macOS app that combines window management (based on [Rectangle](https://github.com/rxhanson/Rectangle)) with clipboard management and an skhd-style hotkey system.

## Attribution

rawm is built on top of [Rectangle](https://github.com/rxhanson/Rectangle) by Ryan Hanson, which is itself based on Spectacle. Rectangle is licensed under the MIT License. See LICENSE for details.

## System Requirements

macOS 10.15 or later.

## Features

- Window snapping and keyboard shortcuts (from Rectangle)
- Clipboard history manager (from Maccy — coming soon)
- skhd-style configurable hotkey engine (coming soon)

## How to use it

Drag a window to the edge of the screen to snap it, or use keyboard shortcuts to resize and position windows.

See [Rectangle's documentation](https://github.com/rxhanson/Rectangle) for the full list of window management actions.

## Building from source

1. Open `Rectangle.xcodeproj` in Xcode
2. Resolve Swift Package dependencies (Xcode will do this automatically)
3. Build and run the `rawm` scheme

## Accessibility Permission

rawm requires Accessibility permission to control window positions. On first launch, macOS will prompt you to grant this permission in System Settings > Privacy & Security > Accessibility.

## License

MIT License. See LICENSE for details.
