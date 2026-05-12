# GitHub Readiness Notes

This repository is close to being presentable as YC Cast, but there are two different cleanup levels:

## Ready Now

- The public README describes YC Cast and the Mac-to-iPad workflow.
- `make_app.sh` no longer contains a personal Developer ID or Team ID.
- `package_ios_ipa.sh` no longer contains a personal DerivedData path.
- Generated distribution artifacts are ignored through `/dist/`, `*.app`, `*.dmg`, `*.ipa`, and related build rules.
- The user-facing macOS and iOS bundle display names are `YC Cast`.
- The local discovery service is `_yc-cast._tcp`.
- Release notes now describe the current YC Cast v8 work instead of old product history.

## Still Worth Doing Before A Fully Public Launch

- Decide whether to keep the GPL license. The current license is GPLv3; if this project is derived from GPL code, keep the license and preserve any required notices.
- Rename internal SwiftPM targets and source folders from `BetterCast*` to `YCCast*` if you want the source tree itself to be fully branded.
- Remove or archive dormant Android, Windows, Linux, and desktop receiver modules if YC Cast will stay Mac+iPad only.
- Add a GitHub release workflow after you have a Developer ID certificate and notarization credentials.
- Add screenshots or a short demo GIF to the README after the UI is stable.

## Release Asset Policy

Do not commit built apps, DMGs, IPAs, or zip files. Put them in GitHub Releases so the source repository stays clean and reviewable.
