# SayType

Tiny macOS menu-bar dictation app using Apple native on-device speech.

## MVP

- Hotkey: `Option+Space`
- Press once to record, press again to finish and paste.
- Uses macOS 26 `SpeechAnalyzer` + `DictationTranscriber`.
- The menu-bar icon changes color and symbol for ready, hotkey, preparing, recording, finishing, pasting, finished, and error states.

## Build

```bash
scripts/test.sh
scripts/install-dev.sh
```

`scripts/install-dev.sh` installs and opens the app at `~/Applications/SayType.app` by default. Use `SAYTYPE_DEV_APP=/path/to/SayType.app` to choose a different stable dev path.

To also start SayType automatically when you log in:

```bash
SAYTYPE_INSTALL_LOGIN_ITEM=1 scripts/install-dev.sh
```

This installs a per-user LaunchAgent at `~/Library/LaunchAgents/com.matthewowusu.saytype.login.plist`. You can inspect or remove it with:

```bash
scripts/install-login-item.sh --status
scripts/install-login-item.sh --uninstall
```

On first launch, grant Microphone, Speech Recognition, and Accessibility. Accessibility is needed so SayType can observe `Option+Space` globally and post `Command+V` after copying the transcript.

## Domain vocabulary

SayType loads domain terminology from:

```text
~/Library/Application Support/SayType/dictionary.json
```

If the file does not exist, SayType creates an empty local dictionary. `hints` are passed to Apple's speech recognizer as short contextual phrases, and optional `replace` entries are exact phrase rewrites applied before the transcript is pasted. Edits are picked up at the start of the next dictation session.

## Signing

macOS Accessibility trust is tied to the app's code identity. The build script auto-detects a real codesigning identity, preferring `Apple Development`, then `Developer ID Application`, then any valid codesigning identity.

If there is no valid identity, SayType is signed ad-hoc and macOS may ask for Accessibility again after rebuilds. Either add an Apple Development certificate through Xcode or run:

```bash
scripts/create-local-signing-identity.sh
scripts/install-dev.sh
```

The local identity helper creates a `SayType Local Development` code-signing certificate in your login keychain, which may trigger a macOS authentication prompt once.
