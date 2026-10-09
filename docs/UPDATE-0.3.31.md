# Ediz OS 0.3.31 — signing recovery and quality of life

The previous signed app used a free Personal Team profile issued on 1 October and expiring on 8 October 2026 at 20:40 in Berlin. The website remains reachable. Apple signing was renewed after the owner signed back into Xcode. The new profile expires on 16 October at 14:57 in Berlin. iOS must trust the renewed developer certificate before launch.

| Before | After | Why |
| --- | --- | --- |
| Signing expired without an in-app explanation | Settings shows the actual signed profile expiry; Today warns within 48 hours | Make the required Mac refresh predictable |
| A successful compile could be followed by installing an expired or nearly expired build | Installation checks the app identifier and requires at least 24 hours of remaining signing validity | Avoid shipping a build that immediately becomes unavailable |
| Repeated manual commands were needed | `npm run check`, `npm run ios:install`, `npm run ios:health` | A repeatable development and refresh path |
| Device build output lived in temporary folders | Default build location is `.native-build/`, ignored by Git and Vercel | Keep useful local output without uploading signed app/private data |
| Gym card could retain an old workout after editing | Returning to Spaces rereads the saved Gym state | Show the actual plan immediately |
| Voice Search could finish transcription after leaving the screen | Leaving cancels its owned task and guards the final result | Prevent offscreen searches and stale state updates |
| Handoff still described an older release | Current release and refresh commands are recorded in the handoff | Reduce confusion for subsequent development |

`npm run check` includes JS/API, Swift core, Python signing-health tests and the web build. `npm run ios:install` uses the existing signing identity and paired device, enables automatic provisioning, validates the build and then installs/launches without uninstalling. `EDIZ_TEAM_ID`, `EDIZ_DEVICE_ID` and `EDIZ_BUILD_PATH` are optional overrides; the script does not infer an owner among multiple identities/devices.

The application reads expiry metadata for display; this is not signature validation. iOS validates signing when installing and launching. Personal Team profiles last seven days from issuance, rather than from each reinstall. The app cannot renew itself. No paid membership, background automation or new backend deployment is introduced. [Apple account and Personal Team limits](https://developer.apple.com/help/account/basics/about-your-developer-account).

Validation status and physical screenshots are recorded in the user-facing 0.3.31 report. Private data and credentials stay outside Git and Vercel. The existing draft PR remains unmerged.
