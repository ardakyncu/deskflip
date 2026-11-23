# Deskflip

<img src="assets/icon.png" width="128" alt="Deskflip app icon">

> One-click menu bar toggle for macOS natural scrolling. For people who switch between a trackpad and a mouse.

## Why

I use my Mac in two very different ways.

**At work** it's just the MacBook: trackpad, fingers, natural scrolling. Swipe up, the page goes up, like a phone. Feels right.

**At home** it's plugged into a monitor with a keyboard and mouse. And with a mouse wheel, natural scrolling feels upside down. My brain expects the wheel to work the "old" way.

macOS doesn't let you set the two separately. The "Natural scrolling" switch in Trackpad settings and the one in Mouse settings are the *same* setting. Flip one and the other flips too. So every time I switched between desk and laptop, I was digging through System Settings → Trackpad → Scroll & Zoom to flip it again. Several times a week. Every week.

Deskflip puts that one switch in the menu bar. One click when I sit down at my desk, one click when I take the laptop to work. That's it.

## Usage

- **Left-click** the menu bar icon to toggle natural scrolling. The change applies right away, no logout needed.
- **Right-click** (or Control-click) for the menu: Natural scrolling, Open at Login and Quit Deskflip.
- The icon shows the current state: a **filled** screen means natural scrolling is on, an **outlined** screen means it is off.

The icon also follows changes made elsewhere, for example in System Settings.

## Install

Requires macOS 13 (Ventura) or later.

### Download

1. Download the latest `Deskflip-x.y.z.zip` from [Releases](https://github.com/ardakyncu/deskflip/releases/latest).
2. Unzip it and move `Deskflip.app` to `~/Applications` (or `/Applications`).
3. Open it. Deskflip lives in the menu bar and has no Dock icon.

### Build from source

Needs the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/ardakyncu/deskflip.git
cd deskflip
make install
```

`make install` builds the app, copies it to `~/Applications` and opens it. `make build` only builds `build/Deskflip.app`.

### First launch

The app is not notarized (it is only ad-hoc signed), so macOS blocks it the first time. Either right-click the app and choose **Open**, or remove the quarantine flag:

```bash
xattr -dr com.apple.quarantine ~/Applications/Deskflip.app
```

On macOS 15 and later, right-click → Open no longer works. Use the `xattr` command, or try to open the app once and then click **Open Anyway** in System Settings → Privacy & Security.

## How it works

macOS stores natural scrolling in a single global default, `com.apple.swipescrolldirection`, shared by the trackpad and the mouse. When you click the icon, Deskflip:

1. Writes the new value with `defaults write -g com.apple.swipescrolldirection -bool YES|NO`.
2. Calls `setSwipeScrollDirection`, a private function in `PreferencePanesSupport.framework`, loaded at runtime. This is what applies the change immediately instead of after the next login.
3. Posts `SwipeScrollDirectionDidChangeNotification` so other apps notice. Deskflip listens for the same notification to keep its icon in sync.

**Caveat:** step 2 uses a private macOS API, which Apple could change or remove in a future macOS. If that happens, Deskflip still saves the setting, but it only takes effect after you log out and back in. The tooltip tells you when that is the case.

## Uninstall

```bash
make uninstall
```

Or quit Deskflip from its menu and delete `Deskflip.app`. If you turned on Open at Login, turn it off first (or remove Deskflip in System Settings → General → Login Items).

## License

[MIT](LICENSE)
