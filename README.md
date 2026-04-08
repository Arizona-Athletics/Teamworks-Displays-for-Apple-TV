# Teamworks Displays for TV

Apple TV (tvOS) app that displays the Teamworks web experience in a full-screen web view and keeps playback running for venue displays.

## Overview
- Loads `https://displays.tw` in a fullscreen web view.
- Disables the idle timer so the Apple TV doesn’t sleep while running.
- Uses a UIKit `UIViewController` wrapped in SwiftUI (`UIViewControllerRepresentable`).
- Adds an autoplay loop that nudges embedded YouTube/video elements to play.
- Shows a brief loading screen on first launch to allow network startup.

## Project layout
- `TeamWorks Arizona/ContentView.swift`: SwiftUI root view that hosts the web view.
- `TeamWorks Arizona/TeamWorks_ArizonaApp.swift`: App entry point; disables idle timer.
- `TeamWorks Arizona/TeamworksWebViewController.h` / `.m`: UIKit controller with runtime WKWebView/UIWebView setup and autoplay logic.
- `TeamWorks Arizona.xcodeproj`: Xcode project.

## Build and run
1. Open `TeamWorks Arizona.xcodeproj` in Xcode.
2. Select a tvOS simulator or a connected Apple TV device.
3. Build and run.

## Configuration
- To change the URL that loads on launch, edit `TeamWorks Arizona/ContentView.swift` and update the `urlString`.

## Notes
- The web view is created via runtime lookup to avoid compile-time availability issues on tvOS.
- Autoplay attempts run on a timer to keep embedded videos active.

## License
MIT License. See `LICENSE`.
