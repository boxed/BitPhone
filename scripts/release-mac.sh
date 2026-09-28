#!/usr/bin/env bash
# Build a Developer ID signed, notarized and stapled Bit.app (universal), zip
# it, and publish it to the GitHub Releases page as mac-v<MARKETING_VERSION>.
#
#   scripts/release-mac.sh
#
# Notary credentials come from a notarytool keychain profile
# (BIT_NOTARY_PROFILE, default "turbokod-notary": an App Store Connect API
# key for the team, so it works for any of the team's apps).
set -euo pipefail
cd "$(dirname "$0")/.."

die() { echo "[release] error: $*" >&2; exit 1; }
note() { echo "[release] $*" >&2; }

profile="${BIT_NOTARY_PROFILE:-turbokod-notary}"
team="B6FVY827P9"
build=".build/release"
app="$build/Build/Products/Release/Bit.app"
zip="$build/Bit-macos.zip"

xcrun notarytool history --keychain-profile "$profile" >/dev/null 2>&1 \
  || die "notarytool keychain profile '$profile' not found"
security find-identity -v -p codesigning | grep -q "Developer ID Application: .*($team)" \
  || die "no Developer ID Application identity for team $team in the keychain"
git diff --quiet HEAD || die "working tree has uncommitted changes"

version="$(xcodebuild -scheme BitMac -configuration Release -showBuildSettings 2>/dev/null \
  | awk '$1 == "MARKETING_VERSION" {print $3; exit}')"
[ -n "$version" ] || die "could not read MARKETING_VERSION"
tag="mac-v$version"
gh release view "$tag" >/dev/null 2>&1 && die "release $tag already exists; bump MARKETING_VERSION"
note "releasing Bit $version for macOS ($tag)"

note "building..."
rm -rf "$build"
xcodebuild -scheme BitMac -configuration Release -derivedDataPath "$build" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="$team" ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build | grep -E "error|warning: |BUILD" >&2
[ -d "$app" ] || die "build failed"
codesign --verify --deep --strict "$app" || die "signature verification failed"

note "notarizing (this can take a few minutes)..."
ditto -c -k --keepParent "$app" "$zip"
xcrun notarytool submit "$zip" --keychain-profile "$profile" --wait \
  | tee /dev/stderr | grep "status: Accepted" >/dev/null || die "notarization failed"
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute "$app" || die "Gatekeeper rejects the app"

# Re-zip so the download carries the stapled ticket.
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"

note "publishing..."
git tag "$tag"
git push origin "$tag"
gh release create "$tag" "$zip" --title "Bit $version for macOS" --notes \
"The bit floats on top of your other windows and answers your questions.

Download Bit-macos.zip, unzip it, and move Bit.app to Applications. Universal (Apple silicon and Intel), macOS 12 or later. Signed with Developer ID and notarized by Apple."

note "done: $(gh release view "$tag" --json url -q .url)"
