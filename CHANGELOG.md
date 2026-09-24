# Changelog

## 2.0.2 - 2026-09-24

- Correct the app bundle version metadata so `CFBundleShortVersionString` and
  `CFBundleVersion` match the current source release line instead of the stale
  1.0.0 value.
- Clarify local code-signing documentation: the install script uses the stable
  `StashBar Local Dev` identity only when it already exists, otherwise it falls
  back to ad-hoc signing.
- Add repository-contract coverage and GitHub Actions CI to keep release
  metadata, documentation links, and build/test checks from drifting again.

## 2.0.1 - 2026-09-24

- Embedded the existing menu-bar screenshot in both English and Chinese
  READMEs.

## 2.0.0 - 2026-09-24

- Rebuilt StashBar around real menu-bar detection, a downward drawer panel, and
  click forwarding for stashed status items.

## 1.0.0 - 2026-09-24

- Initial StashBar menu-bar drawer for notched MacBooks.
