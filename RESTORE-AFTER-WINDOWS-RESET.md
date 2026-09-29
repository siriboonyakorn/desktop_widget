# Restore the desktop widgets after resetting Windows

This guide restores the clock, media controls, calendar, battery, weather, photo, app dock, quick note, system monitor, quick-folder dock, and customization panel.

**Before resetting Windows, copy the widget folder to a USB drive, an external drive, or a cloud backup.** Do not rely on a copy on the Windows drive surviving the reset. This guide alone cannot recreate the widget: you need its script files too.

## 1. Back up before the reset

1. If you have a quick note, click **Done** to save it.
2. Double-click **Stop Widget.cmd**.
3. Copy the entire `desktop_widget` folder to your backup location.
4. Open the backup and check that the files below are present.

Example installation folder:

```text
C:\Users\YOUR-NAME\Documents\desktop_widget
```

### Files needed to run the widgets

Keep these files together in the same folder:

```text
Start Widget.vbs
Customize Widgets.vbs
Stop Widget.cmd
ClockWidget.ps1
CornerWidgets.ps1
MediaControls.ps1
MediaSession.ps1
WeatherWidget.ps1
PhotoWidget.ps1
WidgetCustomization.ps1
WidgetSettings.ps1
AppDock.ps1
QuickNote.ps1
SystemMonitor.ps1
QuickFolders.ps1
CompanionWidgets.ps1
Enable-WidgetStartup.ps1
```

Also keep `README.md`, this guide, and the `Test-*.ps1` files for reference and troubleshooting.

### Your personal settings and notes

Back up these files **if they exist**:

| File | What it preserves |
| --- | --- |
| `settings.json` | Clock style and text color |
| `widget-settings.json` | Shared theme, accents, sizes, positions, visibility, and content preferences |
| `photo-settings.json` | The chosen photo's file path; back up the photo itself separately |
| `dock-settings.json` | Your five app shortcuts and their order |
| `folder-settings.json` | Your quick-folder choices |
| `quick-note.txt` | Your saved quick note |
| `companion-state.json` | Today's estimated active time and the pet's mute/snooze preferences |

Some of these files only appear after you change a setting or write a note. If the note reports a save failure, copy its text somewhere safe before closing the widget. Preserve `quick-note.txt.tmp` too if present; it may contain an unsaved version.

**These personal files are excluded by `.gitignore`.** A Git repository backup alone may not contain your settings or note. Copy the actual files or the whole folder.

The folder shortcuts do not back up the folders' contents. Back up your documents and projects separately. App shortcuts do not back up the apps themselves.

## 2. Put the folder back after resetting Windows

1. Finish Windows setup and sign in to your usual account.
2. Copy the backed-up folder into a permanent, writable location, such as:

   ```text
   C:\Users\YOUR-NAME\Documents\ChatGPT\desktop_widget
   ```

3. If your backup is a ZIP, **extract it first**. Do not launch the widget from inside the ZIP.
4. Keep all the required files together. Restore any saved settings and `quick-note.txt` into this same folder.

The folder does not have to use the old Windows username or original location. The scripts find each other relative to their folder. However, saved app and folder shortcuts may need updating afterward.

The widgets use **Windows PowerShell 5.1 and Windows' built-in WPF/.NET components**. You do not need ChatGPT, Codex, Python, Node.js, PowerShell 7, or developer tools to run them. Internet access is needed for weather; the other widgets work locally. Media controls need a player that exposes its playback session to Windows.

## 3. Start the widgets

Double-click **Start Widget.vbs**.

- The clock and media controls appear in the center.
- Hover near the top-left for the calendar and battery cards.
- Hover near the top-center for the system monitor.
- Hover near the top-right for weather, and below it for the quick note.
- Hover near the left edge for the app dock.
- Hover on the right below the note for the quick-folder dock. On shorter screens it sits beside the right-hand cards.

The hover cards stay behind normal applications, so return to the desktop to see them. CPU needs a sampling interval for its first reading, and weather may take a moment to load.

### If double-clicking the launcher does nothing

Open the restored folder in File Explorer, type `powershell` in its address bar, and press Enter. In that window, run:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File ".\ClockWidget.ps1"
```

This also works if VBScript is unavailable or disabled. Keep the terminal open while using this troubleshooting launch. Any startup error should appear there; copy the error before closing it.

The command's execution-policy setting applies to that PowerShell process; it does not permanently change the computer's execution policy. Use it only with your trusted backup. A managed work/school computer may enforce additional restrictions.

## 4. Reconnect apps and folders

After a Windows reset, app installations, usernames, and folder paths can change.

### App dock

1. Reinstall the apps you want to use.
2. Create desktop shortcuts for them if needed.
3. Reveal the dock, right-click it, and choose **Change app 1...** through **Change app 5...**.
4. Select each app's new `.lnk` or `.url` shortcut.
5. Drag icons to reorder them if desired.

Old shortcuts pointing to missing installations will not work simply because they were backed up.

### Quick-folder dock

Reveal it, right-click, and choose **Change folder 1...** through **Change folder 4...**. Select the folders on your restored computer. Update the project-folder shortcut too if you moved `desktop_widget`.

Your clock preferences and saved note should load automatically when their files are restored. Clock style and color can also be changed by right-clicking the clock.

## 5. Optional: start automatically when you sign in

First confirm that the widgets launch correctly by hand.

1. Press **Win + R**, enter `shell:startup`, and press Enter.
2. Create a **shortcut to Start Widget.vbs** inside that Startup folder.
3. Leave the actual widget files in their permanent folder. Do not move only the launcher into Startup.

If VBScript does not work, create a shortcut with this target instead, replacing `YOUR-NAME` and the folder location:

```text
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "C:\Users\YOUR-NAME\Documents\ChatGPT\desktop_widget\ClockWidget.ps1"
```

Put that shortcut in `shell:startup`. Use only one startup shortcut. Remove it to disable automatic startup. If you later move the widget folder, update the shortcut target.

## 6. Stop or troubleshoot

- **Stop everything:** double-click `Stop Widget.cmd` in the same folder as the running widget.
- **Cards seem missing:** return to the desktop and hover over their locations. They are normally hidden.
- **Weather unavailable:** check your internet connection. The widget retries automatically.
- **Media says “Play a video to connect”:** start playback in a compatible browser/player. Some players do not expose media controls to Windows.
- **Note or settings will not save:** use a folder you can write to, such as Documents. If cloud storage is involved, make the files available locally.
- **Clock time is wrong:** check Windows' date, time, and time-zone settings.
- **Still will not start:** use the visible PowerShell command in section 3 and keep the exact error message.

## No notification installation is needed

The notification experiment was cancelled. The current widgets do **not** need Developer Mode, a trusted signing certificate, an MSIX installation, or Windows notification access.

You can omit these old experimental files/folders from a clean backup:

```text
NotificationApp\
installer\
tools\
NotificationWidget.ps1
Build-NotificationApp.ps1
Build-SignedNotificationApp.ps1
Install-NotificationApp.ps1
Trust-WidgetCertificate.ps1
```

Do not run those installers to restore the current widgets. Preview images, `status.json`, `stop.request`, and diagnostic logs are not needed either. `Start-DesktopWidget.ps1` is an optional compatibility launcher; the normal launcher goes directly to `ClockWidget.ps1`.
