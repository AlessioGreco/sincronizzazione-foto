# SincronizzaFoto - User guide

> **Android only.** This program copies files from **Android** phones over a USB cable. iPhones and iPads are not supported.

## 1. What it does

SincronizzaFoto copies the photos, videos and other files from your Android phone to your PC.

- It only copies what is **new**. You can run it again and again: files already on the PC are skipped.
- It **never deletes** anything from the phone and never overwrites a file on your PC.
- Nothing is installed on the phone, and nothing is installed on the PC either: it is just a folder you double-click.

## 2. Before you start (30 seconds)

1. Connect the phone to the PC with a USB cable. Use a cable that carries data, not only power.
2. **Unlock the phone.**
3. On the phone, open the notification that says something like *Charging this device via USB* and choose **File transfer** (some phones call it *MTP*).
4. Double-click **Start.bat**. The name of your phone appears next to **Phone**. If it does not, press **Refresh**.

> If the phone asks *Allow access to data?*, tap **Allow**.

## 3. First time: use the Quick setup

When there are no rules yet, the program offers the **Quick setup**. You can also open it any time with the **Quick setup...** button.

1. Pick a **base folder** on your PC, for example `D:\Phone`.
2. Tick what you want to copy. *Camera* and *Screenshots* are ticked for you.
3. Choose how to organize the files (see section 5 - it is the most important choice).
4. Press **Create rules**, then **Start copy**.

Each thing you ticked becomes a **rule**: *"take the files from this folder of the phone and put them in that folder of the PC"*. You can change or add rules whenever you like. Use the switch on each rule to turn it on or off.

## 4. A rule, step by step

Double-click a rule (or press its pencil icon, or **Add rule...** for a new one). The editor has six steps.

### 1. Name

Anything you like. It is only used to recognize the rule in the list.

### 2. Folder on the phone

The path of the folder **inside the phone's internal storage**. The easiest way is the **Browse phone...** button: open the folders and pick the one you want. (The phone must be connected.)

Common Android folders:

- `DCIM\Camera` - photos and videos taken with the camera.
- `Pictures\Screenshots` - screenshots.
- `Android\media\com.whatsapp\WhatsApp\Media\WhatsApp Images` - WhatsApp photos (Android 11 and newer). On older phones: `WhatsApp\Media\WhatsApp Images`.
- `Android\media\com.whatsapp\WhatsApp\Media\WhatsApp Video` - WhatsApp videos.
- `Download`, `Documents`, `Movies`, `Music`, `Recordings` - what the names say.

Not every phone uses exactly the same names. If the program says the folder was not found, use **Browse phone...**.

### 3. Save to

The folder on your PC where the files will go. It is created if it does not exist. Folders inside your user folder are stored as `%USERPROFILE%\...`, so the rules also work on another PC.

### 4. What to copy

- **Everything in the folder** - all files.
- **Only these types of file** - tick Photos, Videos, Audio and/or Documents. You can add other extensions, for example `pdf, zip, apk`.

### 5. Also copy the subfolders

Tick it when the phone folder contains other folders you want too (for example *Download*, or the *Sent* folder inside WhatsApp Images). For the camera you normally leave it off.

### 6. How to organize the files on the PC

This decides **where inside the destination folder** each file is saved. The editor shows an example path that changes as you choose.

## 5. Choosing the organization (the part everyone asks about)

Imagine these files on the phone, and a destination folder `D:\Phone\Camera`:

```
IMG_20261117_105300.jpg      (taken on 17 Nov 2026)
IMG_20250102_101010.jpg      (taken on 2 Jan 2025)
Trips\beach.jpg              (inside a subfolder called Trips)
```

(The examples assume **Also copy the subfolders** is ticked, otherwise `beach.jpg` is not copied at all.)

### Everything in one folder (like on the phone)

This is the default. All files go straight into the destination folder, with no subfolders - exactly like on the phone.

```
D:\Phone\Camera\IMG_20261117_105300.jpg
D:\Phone\Camera\IMG_20250102_101010.jpg
D:\Phone\Camera\beach.jpg
```

Choose it if you just want **a copy of everything**, or if you already have your photos in a single folder.

### One folder per year

```
D:\Phone\Camera\2026\IMG_20261117_105300.jpg
D:\Phone\Camera\2025\IMG_20250102_101010.jpg
```

Choose it for big libraries when you want a few big folders.

### One folder per month

```
D:\Phone\Camera\2026-11\IMG_20261117_105300.jpg
D:\Phone\Camera\2025-01\IMG_20250102_101010.jpg
```

Choose it if you like to browse by date. The date is read from the file name (`IMG_20261117_...`). If the name has no date, the file's modified date is used. If even that is not available, the file goes into a folder called *No date*.

### Keep the phone's subfolders

Recreates the same folders as on the phone. It needs **Also copy the subfolders** (the editor ticks it for you).

```
D:\Phone\Camera\IMG_20261117_105300.jpg
D:\Phone\Camera\IMG_20250102_101010.jpg
D:\Phone\Camera\Trips\beach.jpg
```

Choose it for *Download*, *Documents* or WhatsApp, where the folder structure means something.

### Which one should I pick?

- *"I want it exactly like on the phone, everything in one folder."* - **Everything in one folder**.
- *"I want to find photos by when they were taken."* - **One folder per month** (or per year if you have a lot of photos).
- *"I want to keep my Download folder tidy as it is on the phone."* - **Keep the phone's subfolders**.

> **Changing your mind later.** The program looks for copies where it would save the file (and, for the year/month options, also in the main folder). If you switch a rule that already copied photos from *one folder per month* to *everything in one folder*, the photos already inside the month folders would not be recognized and would be copied again. That is why, when you change a rule's organization or its destination folder, the program offers to **tidy up the files already copied**.

### Tidying up files that are already copied

You can also start it any time with the **Tidy up** icon on a rule. It first shows how many files it would move and a few examples, and nothing happens until you press **Move files**.

- It only **moves** files on your PC. It never deletes, never overwrites and never touches the phone.
- It looks at the files in the destination folder itself and in year or month folders (like `2026` or `2026-11`). **Any other subfolder is left alone**, in case it is yours.
- A file stays where it is if its new place already holds a file with the same name. The summary tells you how many.
- Date folders left empty are removed.
- It is not available for *Keep the phone's subfolders*, because the original folders are not known. Choose another organization first.
- When you change the destination folder, it moves the files from the old folder into the new one, using the new organization.

## 6. Running a copy

1. Switch on the rules to run (the switch on each rule).
2. Press **Start copy**.

The window shows what is happening:

- **Step 1/2 - Reading the phone.** A counter shows how many items were read. Big folders (WhatsApp with thousands of photos) can take a minute or two.
- **Step 2/2 - Copying.** The progress bar, the file being copied, and the counters *Copied*, *Already there* and *Errors*.
- When it ends you get a summary for each rule, and the rule list shows *last sync: ...*.

You can press **Stop** at any time. Nothing breaks: next time the files already copied are skipped.

### What the log says

- `Camera: 1055 files found` - how many files the rule found on the phone.
- `Copying: IMG_... (3.5 MB)` - a new file is being copied.
- `A different file named '...' already exists: saved as '... (1).jpg'` - the program never overwrites: a *different* file with the same name was already on your PC, so the new one got a number.
- `ERROR (incomplete or timed out)` - the phone stopped answering (locked screen, unplugged cable). Run it again: only the missing files are copied.

Tick **Also show files that are already there in the log** if you want to see the skipped files too.

## 7. Sharing with a friend (portable)

- **The whole program is one folder.** Copy it to a USB stick or zip it: nothing needs to be installed. Your rules are stored in `config.json` inside the folder.
- **Only the rules:** press **Export rules...**, send the `.json` file, and your friend presses **Import rules...**. Paths under the user folder adapt to their PC automatically. Remember to check the destination folders with the pencil icon of each rule.
- Do not share `history.json`: it only contains *your* last-sync times.

## 8. Troubleshooting

**"No phone found."**
Check the cable (a charge-only cable does not work), unlock the phone, choose **File transfer** in the USB notification, then press **Refresh**.

**"Folder not found on the phone."**
The path is different on your phone. Open the rule, use **Browse phone** and pick the folder. WhatsApp changed its folder in Android 11: try `WhatsApp\Media\WhatsApp Images` on older phones.

**It is very slow.**
Folders with thousands of files take time to read, and the phone is the bottleneck, not the PC. The window stays usable and you can press **Stop**. The second time is much faster because most files are already there.

**Windows says it protected your PC / "scripts are disabled".**
Start the program with **Start.bat**. It starts PowerShell with the right option for this program only; it does not change any Windows setting. If SmartScreen warns about a downloaded file, choose *More info* and then *Run anyway* (the program is open source: you can read it).

**Some files were not copied.**
Check that the rule is switched on, that **What to copy** is not limited to some types, and that **Also copy the subfolders** is on if the files are inside subfolders.

**Windows shows its own "Copying..." window.**
It should not: the program reads the files directly. If your phone does not allow that, the log says *Direct copy is not available on this phone* and the Windows copy is used instead, which can show its own window for big videos. Everything still works.

**Starting over.**
Delete `config.json` (rules) and `history.json` (last-sync times) and start the program again.

## 9. Good to know

- Only **Android** phones work (they connect as *MTP* devices). iPhones do not.
- Files are recognized as *already copied* when a file with the **same name and the same size** is in the destination. Renaming a file on the PC makes the program copy it again.
- Nothing is ever deleted from the phone.
- Look and language: use the **IT / EN** selector and the sun/moon button at the top right (the theme follows Windows unless you choose one).
- The program is free and open source (MIT license). Made by GAle and Claude. WhatsApp, Android and other names are trademarks of their owners; this project is not affiliated with them.
