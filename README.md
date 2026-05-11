# Study Timer

A study timer app with subject tags, session history, analytics, and WiFi sync between devices.

---

## Features

- Timer with subject tags (Math, Science, Coding, etc.)
- Session history and daily streaks
- Analytics — daily bar chart and subject breakdown
- WiFi sync between devices (merge, overwrite, or push)
- Export sessions to Excel

---

## Installation

### Downloads

| Platform | Download |
|----------|----------|
| Android | [StudyTimer.apk](https://github.com/Karthik-PM/study_timer/releases/latest/download/StudyTimer.apk) |
| Linux (Debian/Ubuntu) | [study-timer_1.0.0_amd64.deb](https://github.com/Karthik-PM/study_timer/releases/latest/download/study-timer_1.0.0_amd64.deb) |

Or visit the [releases page](https://github.com/Karthik-PM/study_timer/releases/latest) to download manually.

---

### Android (Mobile)

#### Option 1 — Direct download (easiest)

1. Download [StudyTimer.apk](https://github.com/Karthik-PM/study_timer/releases/latest/download/StudyTimer.apk)
2. Tap the downloaded file to install
3. If prompted, enable **Install from unknown sources** in Settings → Security

#### Option 2 — USB install

1. Enable **USB debugging** on your phone (Settings → Developer Options)
2. Connect your phone via USB
3. Run:
   ```bash
   flutter install
   ```

#### Option 3 — Build from source

```bash
flutter build apk --release
# APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

---

### Linux (Desktop)

#### Option 1 — Install the .deb package (easiest)

1. Download [study-timer_1.0.0_amd64.deb](https://github.com/Karthik-PM/study_timer/releases/latest/download/study-timer_1.0.0_amd64.deb)
2. Run:
```bash
sudo dpkg -i study-timer_1.0.0_amd64.deb
```

Then launch it from your application menu or run:

```bash
study-timer
```

To uninstall:

```bash
sudo dpkg -r study-timer
```

#### Option 2 — Build from source

**Requirements:** Flutter 3.x with Linux desktop support enabled.

```bash
# Enable Linux desktop if not already done
flutter config --enable-linux-desktop

# Install dependencies
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev

# Build
flutter build linux --release

# Run directly
./build/linux/x64/release/bundle/study_timer
```

---

## WiFi Sync

Sync sessions between your phone and desktop without internet.

1. On the **host device**, open the Sync tab and tap **Start Sync Server**
2. Note the IP address shown on screen
3. On the **other device**, enter that IP and choose a sync mode:
   - **Merge** — both devices get all sessions from each other
   - **Get from host** — your data is replaced by the host's data
   - **Send to host** — the host's data is replaced by yours
4. Tap **Sync**

> Both devices must be on the same WiFi network.

---

## Maintainer

Karthik — karthikpm066@gmail.com
