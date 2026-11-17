# Contributing

Thanks for helping! Bug reports, translations and pull requests are all welcome.

## Ground rules

- **Android only.** The program talks to the phone as an MTP device through the Windows shell. iPhone support is out of scope.
- **Windows PowerShell 5.1**, no extra modules, no installer. Keep it a plain folder you can copy.
- **Never delete from the phone, never overwrite on the PC.** Any change touching copy logic must keep this true.
- **The UI is WPF** (XAML styles in `ui\`, windows built from PowerShell): no extra framework or package.
- **No third-party logos or trademarked artwork** (WhatsApp, Android...). Use the generic Segoe MDL2 icons; names in text are fine.
- Source files are **UTF-8 with BOM** (needed by Windows PowerShell 5.1 for accented text). `tools\check.ps1` verifies it.

## Layout

```
SincronizzaFoto.ps1   entry point: loads src\*.ps1 and starts the app
src\core.ps1          paths, config.json, history.json, presets, rule helpers
src\i18n.ps1          translations: T 'key' [args]  (strings in lang\*.json)
src\worker.ps1        the copy job; runs in a background STA runspace
src\async.ps1         small background jobs for the UI (phone folder listing)
src\ui-reorg.ps1      "Tidy up existing files" window (the plan and the moves live in core.ps1)
src\shellstream.ps1   direct copy: opens a phone file as an IStream (PIDL -> IShellItem -> BHID_Stream)
src\wpf.ps1           WPF helpers: theme, icons, logo, dialogs, the film-strip progress
src\ui-*.ps1          windows: main, rule editor, phone browser, quick setup, help/about
src\legacy-excel.ps1  one-time import of the old Excel configuration
ui\                   styles.xaml, palette.light.xaml, palette.dark.xaml
assets\               icon.png / icon.ico (run tools\make-icon.ps1 to regenerate)
lang\                 en.json (source of truth), it.json, ...
docs\                 user guides (Markdown, shown inside the program too)
tools\check.ps1       syntax, BOM and translation checks
```

Why a background runspace? Listing a big phone folder through Windows can take minutes in a single blocking call. The UI never waits for it: the worker writes status into a synchronized hashtable and a UI timer reads it.

## Run the checks

```
powershell -ExecutionPolicy Bypass -File tools\check.ps1
```

It checks the syntax of every script, that files with accents have a BOM, that all translation keys used in the code exist, and that every language has the same keys and `{0}` placeholders as `en.json`.

## Working without a phone: fake phone mode

Set `SINCRONIZZAFOTO_FAKE_PHONE` to a folder and it shows up in the program as a phone called **Fake phone (test)**:

```
Fake\Internal storage\DCIM\Camera\IMG_20261117_105300.jpg
Fake\Internal storage\Download\report.pdf
```

```
set SINCRONIZZAFOTO_FAKE_PHONE=C:\path\to\Fake
Start.bat
```

Optionally set `SINCRONIZZAFOTO_FAKE_PHONE_NAME` to give it another name (handy for screenshots).

The first level inside the folder plays the role of the phone's storage ("Internal storage"). Everything - rules, browsing, copying, organization options, duplicate detection - works as with a real phone, except for MTP specifics (very large folders, slow transfers).

## Add a language

1. Copy `lang\en.json` to `lang\<code>.json` (for example `de.json`) and translate the values. Keep the `{0}`, `{1}` placeholders and the `\n` line breaks.
2. Add the code to `Get-SupportedLanguages` in `src\i18n.ps1` and a button to the language selector in `src\ui-main.ps1`.
3. Translate `docs\GUIDE.en.md` to `docs\GUIDE.<code>.md` (optional but great).
4. Run `tools\check.ps1`.

## Pull requests

Keep them focused, say what you tested (real phone or fake phone), and run the checks first.
