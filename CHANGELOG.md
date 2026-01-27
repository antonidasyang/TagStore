# TagStore Changelog

## [1.0.0.2] - 2026-01-22
### Added
- Release version 1.0.0.2.
- **Redesigned Settings**: Implemented a modern, two-column layout for the Settings dialog with categorized navigation.
- **Custom AI Prompt**: Added the ability to customize the System Prompt used for AI tagging, allowing users to fine-tune tag generation rules.

### Changed
- **UI Polish**: Unified button styles across all dialogs to match the application theme.
- **Drop Balloon**: Improved tooltip positioning to follow the mouse cursor without clipping, ensuring hints are always visible.

## [1.0.0.1] - 2026-01-22
### Added
- Release version 1.0.0.1.
- **Singleton Mode**: Prevent multiple instances of the application; secondary launches now bring the existing window to focus.
- **Start with Windows**: Added option in Settings to launch the app automatically on system startup.
- **Improved UI**: Added tooltip hint when hovering over the Drop Balloon.

### Fixed
- Fixed bug where moving folders during import was defaulting to reference mode.
- Fixed **Startup Flicker**: The main window is now hidden by default when "Start Minimized" is enabled.
- Fixed **Trailing Dots**: Removed the redundant dot in generated filenames for folders without extensions.
- Fixed **Stability**: Restored critical system DLLs and optimized deployment cleanup script.

## [1.0.0.0] - 2026-01-22
### Added
- Initial Release version 1.0.0.0.
- **Comprehensive i18n**: Full Chinese (zh_CN) and English (en_US) translation coverage for all UI elements.
- **Metadata**: Embedded version, copyright, and company information into the Windows executable.
- **High-Res Icon**: Generated and embedded a multi-resolution HD icon (16x16 to 256x256).
- **AI-Powered Tagging**: Support for automatic tag generation via OpenAI-compatible APIs.
- **Folder Management**: Support for indexing folders without moving content, or managing them inside the library.
- **Theme Support**: Light, Dark, and System theme synchronization.

---
*Created by Antonidas*
