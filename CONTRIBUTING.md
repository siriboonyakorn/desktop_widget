# Contributing

Use Windows PowerShell 5.1 with `-STA` for WPF. Keep the normal launcher free of administrative requirements and preserve existing preferences. Never commit personal notes, app paths, generated previews or signing material.

Before submitting changes, run `Test-Source.ps1` and the tests for the affected feature. Test UI changes at normal and enlarged display scaling. Include the Windows version, reproduction steps and sanitized screenshots in bug reports. Tests that activate real windows or interact with media should be run deliberately on a local desktop, not against someone's active work.

Small pull requests with a concrete problem, the resulting behavior and relevant test results are easiest to review. The notification-package prototype is inactive; focus new work on the normal PowerShell/WPF runtime.
