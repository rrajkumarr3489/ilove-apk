# I Love Aruppukottai - Flutter app

Only **Bus Timings** is live. The other tiles open an "Under construction" page.

## Who can do what
- **Guest** (no registration): can open the app and view all bus timings, search, bus-stand board, notices, favorites.
- **Registered user**: everything above + add a new bus / add a timing. Every entry is saved with the user's id and is checked by an admin before it appears.
- Login is kept on the phone. Next time the app opens on the home page.

## First run
1. Run DB scripts 01 -> 11 and publish the API (see ilove_bus/README.md).
2. Open the app -> Settings -> **Server address** -> `https://your-api-subdomain` (the `/api/v1` is added automatically).

## Keeping the APK small
- No photos are inside the app. Banners are loaded from your server: upload pictures to the server's media folder and set Settings `Media.BaseUrl` (folder URL) and `Home.Banners` (comma-separated file names).
- Build is split per phone type. Install `app-arm64-v8a-release.apk` on almost every modern phone.
- Maps use OpenStreetMap tiles (free, no key). "Google Maps" buttons open the Google Maps app for the place.

## Build the APK
Push this folder to GitHub -> Actions -> *Build APK* -> download the artifact `ilove-apk`.
