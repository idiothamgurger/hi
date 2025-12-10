#!/bin/bash

echo "attwmcf?"
echo

############################################
# 0. Homebrew (user-level) + 7z + dmg2img #
############################################

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

############################################
# 1. Extraction Type Selection             #
############################################

echo "choose:"
echo "1) dmg > pkg > app (non‑mount)"
echo "2) pkg > app"
echo "3) dmg > app (mount + copy)"
echo "4) dmg > img > mount img > app (fallback)"
read -p "answer: " TYPE

if [[ "$TYPE" != "1" && "$TYPE" != "2" && "$TYPE" != "3" && "$TYPE" != "4" ]]; then
    echo "twin what is that"
    exit 1
fi

############################################
# 2. Ask for File + Output Folder GUI     #
############################################

if [[ "$TYPE" == "2" ]]; then
    FILE_PATH=$(osascript -e 'POSIX path of (choose file with prompt "select pkg to extract:")')
else
    FILE_PATH=$(osascript -e 'POSIX path of (choose file with prompt "select dmg to extract:")')
fi

OUTDIR=$(osascript -e 'POSIX path of (choose folder with prompt "where do i save the files at:")')

############################################
# 3. Setup Working Directories             #
############################################

BASE=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
WORKDIR="$OUTDIR/${BASE}_extracted"
DMG_EXTRACT="$WORKDIR/dmg_extracted"
PKG_EXPAND="$WORKDIR/pkg_expanded"
APP_EXTRACT="$WORKDIR/app_extracted"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR" "$DMG_EXTRACT" "$APP_EXTRACT"

############################################
# 4. Extraction Logic Depending on Option  #
############################################

if [[ "$TYPE" == "1" || "$TYPE" == "4" ]]; then
    echo "attempting non‑mount extraction..."

    echo "trying 7z..."
    7z x "$FILE_PATH" -o"$DMG_EXTRACT" >/dev/null 2>&1 || echo "7z failed, moving on"

    echo "trying dmg2img..."
    IMG_PATH="$WORKDIR/${BASE}.img"
    dmg2img "$FILE_PATH" "$IMG_PATH" >/dev/null 2>&1 || echo "dmg2img failed"

    if [[ "$TYPE" == "4" && -f "$IMG_PATH" ]]; then
        echo "trying to mount img..."
        MOUNT_POINT="$WORKDIR/img_mount"
        mkdir -p "$MOUNT_POINT"
        hdiutil attach "$IMG_PATH" -mountpoint "$MOUNT_POINT" -nobrowse -readonly >/dev/null 2>&1 && MOUNTED=1 || MOUNTED=0

        if [[ $MOUNTED -eq 1 ]]; then
            echo "copying contents..."
            cp -R "$MOUNT_POINT/"* "$APP_EXTRACT/" 2>/dev/null || echo "copy failed"
            hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1
        else
            echo "img mount failed"
        fi
    fi

    if [[ "$TYPE" == "1" ]]; then
        PKG_PATH=$(find "$DMG_EXTRACT" -type f -name "*.pkg" | head -n 1)
        if [ -z "$PKG_PATH" ]; then
            echo "where the fuck is the pkg"
            echo "Are these the world's most crispy fries?"
        else
            echo "pkg found: $PKG_PATH"
        fi
    fi
fi

if [[ "$TYPE" == "3" ]]; then
    echo "mounting dmg..."
    MOUNT_POINT="$WORKDIR/dmg_mount"
    mkdir -p "$MOUNT_POINT"
    hdiutil attach "$FILE_PATH" -mountpoint "$MOUNT_POINT" -nobrowse -readonly >/dev/null 2>&1 && MOUNTED=1 || MOUNTED=0

    if [[ $MOUNTED -eq 1 ]]; then
        echo "copying app to output..."
        cp -R "$MOUNT_POINT/"* "$APP_EXTRACT/" 2>/dev/null || echo "copy failed"
        hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1
    else
        echo "dmg mount failed"
    fi
    PKG_PATH="$APP_EXTRACT"
fi

if [[ "$TYPE" == "2" || ( "$TYPE" == "1" && -n "$PKG_PATH" ) ]]; then
    if [ -f "$PKG_PATH" ]; then
        echo "open pkg"
        rm -rf "$PKG_EXPAND"
        pkgutil --expand "$PKG_PATH" "$PKG_EXPAND" >/dev/null 2>&1 || echo "pkgutil failed, continuing"
        echo "yay"

        echo "where is the fucking payload"
        PAYLOAD_PATH=$(find "$PKG_EXPAND" -type f -name "Payload" | head -n 1)
        if [ -z "$PAYLOAD_PATH" ]; then
            echo "payload found, but continuing"
        else
            echo "payload: $PAYLOAD_PATH"
            echo "open payload"
            ( cd "$APP_EXTRACT" || exit
              cat "$PAYLOAD_PATH" | gunzip -dc | cpio -idmv >/dev/null 2>&1 || echo "payload extraction failed" )
        fi
    fi
fi

############################################
# DONE                                      #
############################################

echo "ok its done"
echo
echo "dmg extracted to        $DMG_EXTRACT"
echo "pkg expanded to         $PKG_EXPAND"
echo "app files extracted to  $APP_EXTRACT"
