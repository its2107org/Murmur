# Murmur

Ian's private dictation app for iPhone. Talk, and get clean, tidy text you can paste anywhere. Everything happens on the iPhone: nothing you say is ever sent anywhere.

- **Action Button:** press once to start listening without opening the app (a recording indicator shows in the Dynamic Island), press again to stop. The tidied text is copied, ready to paste.
- **Spoken commands:** finish with "format as email", "bullet points", "make it a text message", "turn this into notes", "make it shorter", "more formal" or "more casual" and the text is shaped to match.
- **Keyboard:** the Murmur keyboard drops the text straight into whatever you're typing.
- **Widgets:** a Dictate button for the Home Screen and Lock Screen.

## How it stays private

- Speech is turned into text with Apple's on-device speech engine (`SpeechAnalyzer`). iOS downloads Apple's English speech files once; audio never leaves the phone and is never saved.
- Tidying uses Apple's on-device Apple Intelligence model (`FoundationModels`), which runs on the phone, not on Apple's servers.
- The app contains no networking code, no analytics and no third-party packages. `scripts/privacy-check.sh` runs before every build and fails it if any appear.

## How it's built

- Native SwiftUI app (iOS 26+) with a keyboard extension and a widget extension (Home Screen widget plus the Live Activity). The Xcode project is generated from `project.yml` with XcodeGen.
- The app and keyboard share state through the keychain, like Shelf, so no App Group set-up is needed.
- GitHub Actions builds it and sends it to TestFlight, using the same Apple secrets and `Match-Secrets` certificate store as Trio, Nudge and Shelf. It rebuilds on the 1st of each month so it never expires.

## Workflows

1. **Set up with Apple**: `check` the secrets, create the `identifiers`, then `certificates`, then `testers`.
2. **Check build and screenshots**: runs on every push; builds for the simulator, checks the spoken commands and saves screenshots to the `screenshots` branch.
3. **Build Murmur**: builds and uploads to TestFlight. Runs monthly and on demand.
