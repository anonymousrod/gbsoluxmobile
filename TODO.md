# TODO List for GBSolux Mobile App Integration

## Completed Tasks
- [x] Update pubspec.yaml with required dependencies (flutter_inappwebview, file_picker, image_picker, flutter_secure_storage, lottie)
- [x] Run flutter pub get to install dependencies
- [x] Replace main.dart with WebView implementation including splash screen and basic file handling
- [x] Update AndroidManifest.xml with necessary permissions (internet, storage, camera)
- [x] Fix build errors (const Duration, file chooser parameter)
- [x] Start app build and test on emulator

## Pending Tasks
- [x] Remove loader on every page change in WebView - only show during initial app loading
- [x] Implement platform channel for downloads using Android DownloadManager
- [x] Update shouldOverrideUrlLoading to handle PDF/file links by opening externally
- [x] Add app icon for splash screen (assets/ic_launcher.png) - replaced Lottie with round icon animation
- [ ] Implement file uploads via platform channel (currently commented out due to API issues)
- [ ] Verify WebView loads https://app.gbsolux.com correctly on device
- [ ] Test file uploads (gallery, camera, file picker) once implemented
- [ ] Test downloads and notifications
- [ ] Implement full cookie persistence for authentication
- [ ] Add error handling for network issues or site unavailability
- [ ] Optimize performance (preload resources, reduce memory usage)
- [ ] Test on different Android versions (8+)
- [ ] Prepare for Play Store submission (check permissions, policies)

## Notes
- The app now wraps the website in a WebView with basic functionality.
- Splash screen implemented (shows progress indicator, Lottie asset needed).
- File uploads framework ready but needs platform channel implementation.
- Downloads are intercepted but need full Android DownloadManager integration.
- Cookies are synced for auth, but full session management may need backend adjustments.
- Build is in progress on emulator - waiting for completion.
