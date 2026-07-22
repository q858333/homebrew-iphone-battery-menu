#!/usr/bin/env zsh
set -euo pipefail

usage() {
    echo "Usage: ./prepare-release.sh vX.Y.Z"
    echo
    echo "Example:"
    echo "  ./prepare-release.sh v1.0.1"
    echo
    echo "Optional:"
    echo "  TAP_REPO=/path/to/homebrew-iphone-battery-menu ./prepare-release.sh v1.0.1"
}

if [[ $# -ne 1 ]]; then
    usage
    exit 64
fi

TAG="$1"

if [[ ! "$TAG" =~ '^v[0-9]+(\.[0-9]+){1,2}([.-][0-9A-Za-z.-]+)?$' ]]; then
    echo "Invalid tag: $TAG"
    echo "Expected a tag like v1.0.1"
    exit 64
fi

VERSION="${TAG#v}"
ROOT_DIR="$(git rev-parse --show-toplevel)"
APP_DIR="$ROOT_DIR/iPhoneBatteryMenu"
ZIP_FILE="$APP_DIR/iPhoneBatteryMenu.zip"
BRANCH="$(git branch --show-current)"
DEFAULT_TAP_REPO="$(dirname "$(dirname "$ROOT_DIR")")/homebrew-iphone-battery-menu"
TAP_REPO="${TAP_REPO:-$DEFAULT_TAP_REPO}"
TAP_CASK_FILE="$TAP_REPO/Casks/iphone-battery-menu.rb"
TAP_BRANCH=""

if [[ -z "$BRANCH" ]]; then
    echo "Cannot prepare a release from a detached HEAD."
    exit 1
fi

cd "$ROOT_DIR"

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    echo "Tracked files have uncommitted changes. Commit or stash them before preparing a release."
    git status --short
    exit 1
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    echo "Tag already exists locally: $TAG"
    exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
    echo "Tag already exists on origin: $TAG"
    exit 1
fi

if [[ ! -d "$TAP_REPO/.git" ]]; then
    echo "Missing Homebrew tap repository: $TAP_REPO"
    echo
    echo "Clone it first:"
    echo "  git clone https://github.com/q858333/homebrew-iphone-battery-menu.git \"$TAP_REPO\""
    echo
    echo "Or pass a custom path:"
    echo "  TAP_REPO=/path/to/homebrew-iphone-battery-menu ./prepare-release.sh $TAG"
    exit 1
fi

TAP_BRANCH="$(git -C "$TAP_REPO" branch --show-current)"
if [[ -z "$TAP_BRANCH" ]]; then
    echo "Cannot update the tap repository from a detached HEAD: $TAP_REPO"
    exit 1
fi

if [[ -n "$(git -C "$TAP_REPO" status --porcelain)" ]]; then
    echo "Homebrew tap repository has uncommitted changes. Commit or stash them first:"
    echo "  $TAP_REPO"
    git -C "$TAP_REPO" status --short
    exit 1
fi

if [[ ! -f "$TAP_CASK_FILE" ]]; then
    echo "Missing cask file: $TAP_CASK_FILE"
    exit 1
fi

echo "Building iPhoneBatteryMenu.app..."
"$APP_DIR/build-app.sh" >/dev/null

echo "Creating release zip..."
ditto -c -k --keepParent "$APP_DIR/.build/release/iPhoneBatteryMenu.app" "$ZIP_FILE"

SHA256="$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')"

echo "Updating Homebrew cask in tap repository..."
VERSION="$VERSION" SHA256="$SHA256" ruby -0pi -e '
  gsub(/version "[^"]+"/, "version \"" + ENV.fetch("VERSION") + "\"")
  gsub(/sha256 "[^"]+"/, "sha256 \"" + ENV.fetch("SHA256") + "\"")
' "$TAP_CASK_FILE"

git -C "$TAP_REPO" add Casks/iphone-battery-menu.rb
git -C "$TAP_REPO" commit -m "Update iPhoneBatteryMenu to $VERSION"

git tag "$TAG"
git push origin "$BRANCH"
git push origin "$TAG"

git -C "$TAP_REPO" push origin "$TAP_BRANCH"

cat <<EOF

Release preparation complete.

Tag:
  $TAG

Zip to upload manually:
  $ZIP_FILE

SHA256 for Homebrew Cask:
  $SHA256

Updated tap repository:
  $TAP_REPO

Upload the zip to:
  https://github.com/q858333/iPhoneBatteryMenu/releases/tag/$TAG

Then test:
  brew update
  brew reinstall --cask iphone-battery-menu
EOF
