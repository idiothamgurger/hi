#!/bin/bash

BREW_PREFIX="$HOME/homebrew"
BREW_BIN="$BREW_PREFIX/bin/brew"


if [ -x "$BREW_BIN" ]; then
    export PATH="$BREW_PREFIX/bin:$PATH"
fi


if ! command -v brew &>/dev/null; then
    echo "where is homebrew"
    NONINTERACTIVE=1 \
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null
fi

for tool in 7z dmg2img; do
    if ! command -v $tool &>/dev/null; then
        echo "not found specific file thing ($tool)"
        brew install $tool || { echo "failed to install $tool"; }
    fi
done

echo "choose:"
echo "1) dmg > pkg > app"
echo "2) pkg > app"
read -p "answer: " TYPE

if [[ "$TYPE" != "1" && "$TYPE" != "2" ]]; then
    echo "stupid"
    exit 1
fi

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

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR" "$DMG_EXTRACT" "$APP_EXTRACT"

if [[ "$TYPE" == "1" ]]; then
    echo "trying to extract dmg..."

    echo "trying 7z..."
    7z x "$FILE_PATH" -o"$DMG_EXTRACT" >/dev/null 2>&1 || echo "7z failed"

    echo "trying dmg2img..."
    IMG_PATH="$WORKDIR/${BASE}.img"
    dmg2img "$FILE_PATH" "$IMG_PATH" >/dev/null 2>&1 || echo "dmg2img failed"
    if [ -f "$IMG_PATH" ]; then
        echo "7z on img..."
        7z x "$IMG_PATH" -o"$DMG_EXTRACT" >/dev/null 2>&1 || echo "7z on img failed"
    fi

    PKG_PATH=$(find "$DMG_EXTRACT" -type f -name "*.pkg" | head -n 1)

    if [ -z "$PKG_PATH" ]; then
        echo "where the fuck is the pkg"
        echo "Are these the world's most crispy fries?"
        echo 
    else
        echo "pkg found: $PKG_PATH"
    fi
else
    PKG_PATH="$FILE_PATH"
fi

if [ -f "$PKG_PATH" ]; then
    echo "open pkg"
    rm -rf "$PKG_EXPAND"
    pkgutil --expand "$PKG_PATH" "$PKG_EXPAND" >/dev/null 2>&1 || echo "pkgutil failed"
    echo "yay"

    echo "no payload"
    PAYLOAD_PATH=$(find "$PKG_EXPAND" -type f -name "Payload" | head -n 1)

    if [ -z "$PAYLOAD_PATH" ]; then
        echo "payload found"
    else
        echo "payload: $PAYLOAD_PATH"
        echo "open payload"
        (cd "$APP_EXTRACT" || exit
         cat "$PAYLOAD_PATH" | gunzip -dc | cpio -idmv >/dev/null 2>&1 || echo "payload failed")
    fi
fi

echo "ok its done"
echo
echo "dmg extracted to        $DMG_EXTRACT"
echo "pkg expanded to         $PKG_EXPAND"
echo "app files extracted to  $APP_EXTRACT"
