# Lights

An iPhone app that controls Tuya Bluetooth bulbs (sold under the Smart Life / Tuya brands) without the Tuya cloud, an account, or the Smart Life app.

Many cheap Tuya Bluetooth bulbs don't take a normal Bluetooth connection. Smart Life controls them with **Tuya Beacon**: the phone broadcasts short frames, every bulb nearby listens, and the bulb named in the frame acts on it. The bulbs never reply. Lights records those frames once and then sends them itself, so it works offline with no account.

## Features

- On and off for each lamp, plus All on and All off
- Warm, white and cold, plus eight colours: red, orange, yellow, green, cyan, blue, purple and pink
- **Groups:** control several lamps as one, with power, whites and colours
- **Scenes:** one tap sets each lamp to its own state, for example two lamps warm, one red, two off; lamps a scene doesn't mention are left alone
- **Arrange mode:** tap Edit to drag tiles into your order, rename lamps, and edit or delete scenes and groups
- English and Portuguese, set in Settings; English is the default
- No network access, no account and no analytics; everything stays on the phone

Brightness isn't supported, because a command only works if it was recorded first (see [Limitations](#limitations)).

## How it works

Each command is a 26-byte frame, broadcast as 13 16-bit Bluetooth service UUIDs (each UUID little-endian):

| Bytes | Field |
|---|---|
| 0 | `0x0b` |
| 1–4 | Lamp address (node) |
| 5–6 | Frame counter, big-endian |
| 7 | Frame type: `05` is a command, `01` is a status query |
| 8–24 | Encrypted payload, 17 bytes |
| 25 | CRC-8, polynomial `0x07`, over bytes 1–24, starting from a seed |

What was found by recording Smart Life:

- **A payload is fixed per lamp and per command.** It doesn't depend on the counter, so a recorded "red" for a given lamp can be sent again and again. Payloads differ between lamps, so each lamp needs its own recording.
- **The counter must go up.** A lamp ignores any frame whose counter isn't higher than the last one it accepted. That last value is shared across its whole Smart Life group, so a frame sent to one lamp raises the bar for the others. Lights keeps one 16-bit counter per group and saves it.
- **The CRC seed differs per group,** so the seed also tells which group a lamp belongs to.
- **White tones are preceded by a white-mode command.** Smart Life sends that command first, and Lights does the same unless the lamp is already showing a white.

iOS can broadcast only one advertisement at a time, so Lights queues frames and sends each one for 0.6 s. Setting five lamps to warm takes a few seconds.

## Setup

You need a Mac with Xcode, an iPhone, and lamps that are already paired in Smart Life.

### 1. Record your lamps

Keep the phone near the Mac, start the recorder, then use Smart Life to tap through every command on each lamp: on, off, warm, white, cold and each colour.

```sh
swift tools/record.swift 300
```

The first time, macOS asks to let your terminal use Bluetooth. The recorder prints one line for each new frame:

```
node      counter type payload                            crc
0a1b0001    118b    05    33c1d2e3f4a5b6c7d8e9fa0b1c2d3e4f50 7c
```

Work through one lamp at a time, in a fixed order, and note which payload came from which button. Within a group, the first two hex digits of a payload are the same on every lamp for a given command (for example `33…` is on, `d6…` is off), which helps tell commands apart. When you pick a white tone, Smart Life sends the white-mode payload first and then the tone.

### 2. Write `TuyaLights/Lamps.json`

Copy `Lamps.example.json` to `TuyaLights/Lamps.json` and fill it in:

```json
{
  "lamps": [
    {
      "name": "Bedside lamp",
      "node": "0a1b0001",
      "seed": "18",
      "counter": "1300",
      "commands": {
        "on": "…", "off": "…", "white": "…",
        "warm": "…", "neutral": "…", "cool": "…",
        "red": "…", "orange": "…", "yellow": "…", "green": "…",
        "cyan": "…", "blue": "…", "purple": "…", "pink": "…"
      }
    }
  ]
}
```

- `node`: the 4-byte address shown by the recorder
- `seed`: the CRC seed for the lamp's group, in hex. To find it, take a recorded frame and try all 256 seeds over bytes 1–24 until the CRC matches the last byte. Every lamp in a group shares one seed.
- `counter`: where to start counting, in hex. Use something higher than any counter the recorder showed for that group.
- `commands`: the 17-byte payloads in hex. `white` is the white-mode command, and `neutral` is the plain white tone.

`Lamps.json` is in `.gitignore`. Anyone who has it can control your lamps from within Bluetooth range, so don't publish it.

Keep a private backup of this file. You can also keep it outside the checkout and
symlink it to `TuyaLights/Lamps.json`. The build checks that the file is present and
matches the bundled resource, so it cannot silently produce an app with no lamps.

### 3. Build

Open `TuyaLights.xcodeproj`, set your own signing team and bundle identifier, and run the app on your iPhone. Bluetooth broadcasting doesn't work in the Simulator.

For a development-signed IPA, the embedded provisioning profile must include your
iPhone and must not have expired. To install without signing it again, unzip the IPA
and drag `Payload/TuyaLights.app` into Xcode's Devices and Simulators window for your
connected iPhone. Free accounts support up to three installed apps, and their builds
expire after seven days; rebuild with Xcode to renew them.

Keep the installed bundle identifier and signing team when updating, and install over
the existing app. Deleting Lights removes its saved counters, scenes and groups.

Sideloadly error `7252` (certificate not found on the team) concerns its Apple signing
request; changing the IPA's bundle identifier does not fix that request. An already
signed build can instead be installed directly through Xcode.

## Limitations

- **Only recorded commands work.** Payloads are encrypted, so new colours or brightness levels can't be generated without the lamp keys and the encryption scheme. Both are still unknown.
- **The lamps never report back.** Lights shows the last command it sent, so changes made in Smart Life or at the wall switch won't appear in the app.
- **Smart Life may be ignored for a while after using Lights,** because its counter is now lower than the one Lights uses. Lights itself always moves its counter forward.
- **Removing a lamp from Smart Life, or resetting it, re-pairs it.** After that, the recorded commands no longer work.
- Lights has been tested with one set of Smart Life RGB+CCT bulbs. Other Tuya Beacon devices may use different frames.

## Project layout

```
TuyaLights/
  Beacon.swift        Lamp library loading, frame building, broadcast queue
  ContentView.swift   Home: scenes, groups, lamps, arrange mode
  LampView.swift      Controls for one lamp or a group
  Scenes.swift        Scenes and the scene editor
  Groups.swift        Groups and the group editor
  LampList.swift      Lamp names and order
  SettingsView.swift  Language
  Language.swift      English and Portuguese strings
  Style.swift         Background and glass styles
tools/record.swift    Mac recorder for Smart Life frames
Lamps.example.json    Template for TuyaLights/Lamps.json
```

## Disclaimer

This project isn't affiliated with or endorsed by Tuya. It only replays frames recorded from your own phone, to control lamps you own.

## License

[MIT](LICENSE)
