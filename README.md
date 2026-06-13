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

On first launch, grant Microphone, Speech Recognition, and Accessibility. Accessibility is needed so SayType can observe `Option+Space` globally and post `Command+V` after copying the transcript.

## Signing

macOS Accessibility trust is tied to the app's code identity. The build script auto-detects a real codesigning identity, preferring `Apple Development`, then `Developer ID Application`, then any valid codesigning identity.

If there is no valid identity, SayType is signed ad-hoc and macOS may ask for Accessibility again after rebuilds. Either add an Apple Development certificate through Xcode or run:

```bash
scripts/create-local-signing-identity.sh
scripts/install-dev.sh
```

The local identity helper creates a `SayType Local Development` code-signing certificate in your login keychain, which may trigger a macOS authentication prompt once.
