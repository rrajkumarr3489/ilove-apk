# I Love APK (I Love Aruppukottai)

Offline demo app. No Play Store, no server.

## Where data lives (on the phone)
- `data.json`  - all text data (bus, temples, shops, news). Notepad-style JSON.
- `images/`    - photos you add from the app.
Both are in the app's private folder; the exact paths are shown in the app under Settings.
Edits made in the app are saved straight into `data.json`.

## Edit the starting demo data
Change `assets/data.json` before building. Sections: `bus`, `temples`, `shops`, `news`.
To make another tile live (train, food...), add a section with the same key in
`assets/data.json` and set `live: true` for that tile in `lib/models.dart`.

## Get the APK (no installs needed on your PC)
1. Create a free GitHub account and a new repository.
2. Upload everything in this folder (including the hidden `.github` folder) to it.
3. Go to the repo -> Actions -> "Build APK" -> Run workflow.
4. After ~5 minutes open the finished run -> Artifacts -> `ilove-apk` -> download, unzip.
5. Copy `app-release.apk` to your phone and install (allow "install unknown apps").

## Later: server sync
All data access goes through `lib/data_store.dart`. When your server is ready,
add a `RemoteStore implements DataStore` that downloads the JSON from the server
(and caches it locally), then change the last line of that file. Screens stay as they are.
