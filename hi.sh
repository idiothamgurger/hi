#!/bin/bash

echo "attwmcf?"
echo

# --- Step 0: Setup user-level Homebrew ---
BREW_PREFIX="$HOME/homebrew"
BREW_BIN="$BREW_PREFIX/bin/brew"

if ! command -v "$BREW_BIN" &>/dev/null; then
    echo "where is homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null
    mkdir -p "$BREW_PREFIX"
    export PATH="$BREW_BIN:$PATH"
    echo "homebrew at $BREW_PREFIX"
else
    echo "ok u have homebrew at $BREW_BIN"
fi

# Check p7zip
export PATH="$BREW_PREFIX/bin:$PATH"
if ! "$BREW_BIN" list p7zip &>/dev/null; then
    echo "not found specific file thing"
    "$BREW_BIN" install p7zip
fi

# --- Step 1: Ask user for extraction type ---
echo "Select extraction type:"
echo "1) dmg > pkg > app"
echo "2) pkg > app"
read -p "Enter 1 or 2: " TYPE

if [[ "$TYPE" != "1" && "$TYPE" != "2" ]]; then
    echo "twin what is that"
    exit 1
fi

# --- Step 2: Select file and output folder ---
if [[ "$TYPE" == "1" ]]; then
    FILE_PATH=$(osascript -e 'POSIX path of (choose file with prompt "select dmg to extract:")')
else
    FILE_PATH=$(osascript -e 'POSIX path of (choose file with prompt "select pkg to extract:")')
fi

OUTDIR=$(osascript -e 'POSIX path of (choose folder with prompt "where do i save the files at:")')

BASE=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
WORKDIR="$OUTDIR/${BASE}_extracted"
DMG_EXTRACT="$WORKDIR/dmg_extracted"
PKG_EXPAND="$WORKDIR/pkg_expanded"
APP_EXTRACT="$WORKDIR/app_extracted"

mkdir -p "$WORKDIR" "$APP_EXTRACT"

# --- Step 3: DMG workflow ---
if [[ "$TYPE" == "1" ]]; then
    mkdir -p "$DMG_EXTRACT" "$PKG_EXPAND"
    echo "extracting dmg"
    7z x "$FILE_PATH" -o"$DMG_EXTRACT" >/dev/null
    echo "yeah"

    echo "searching for pkg in dmg"
    PKG_PATH=$(find "$DMG_EXTRACT" -type f -name "*.pkg" | head -n 1)
    if [ -z "$PKG_PATH" ]; then
        echo "where the fuck is the pkg"
        rm -rf "$WORKDIR"
        echo "fuck you"
        exit 1
    fi
    echo "pkg: $PKG_PATH"
else
    PKG_PATH="$FILE_PATH"
fi

# --- Step 4: Expand PKG ---
mkdir -p "$PKG_EXPAND"
echo "open pkg"
pkgutil --expand "$PKG_PATH" "$PKG_EXPAND"
echo "yay"

# --- Step 5: Extract Payload ---
echo "where is the fucking payload"
PAYLOAD_PATH=$(find "$PKG_EXPAND" -type f -name "Payload" | head -n 1)
if [ -z "$PAYLOAD_PATH" ]; then
    echo "no payload, deleting everything else"
    rm -rf "$WORKDIR"
    exit 1
fi
echo "payload: $PAYLOAD_PATH"

echo "open payload"
(
    cd "$APP_EXTRACT"
    cat "$PAYLOAD_PATH" | gunzip -dc | cpio -idmv
)

echo "completed"
echo "dmg extracted to        $DMG_EXTRACT"
echo "pkg expanded to          $PKG_EXPAND"
echo "app files extracted to  $APP_EXTRACT"
