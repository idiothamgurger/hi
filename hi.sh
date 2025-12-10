#!/bin/bash

echo "attwmcf?"
echo

############################################
# 0. Homebrew (user-level) + 7z + dmg2img #
############################################

BREW_PREFIX="$HOME/homebrew"
BREW_BIN="$BREW_PREFIX/bin/brew"

# Add brew to PATH if it exists
if [ -x "$BREW_BIN" ]; then
    export PATH="$BREW_PREFIX/bin:$PATH"
fi

# Install brew if missing
if ! command -v brew &>/dev/null; then
    echo "where is homebrew"
    NONINTERACTIVE=1 \
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null
fi

# Ensure p7zip and dmg2img are installed
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
echo "1) dmg > pkg > app"
echo "2) pkg > app"
read -p "answer: " TYPE

if [[ "$TYPE" != "1" && "$TYPE" != "2" ]]; then
    echo "twin what is that"
    exit 1
fi

############################################
# 2. Ask for File + Output Folder GUI     #
############################################

if [[ "$TYPE" == "1" ]]; then
    FILE_PATH=$(osascript -e 'POSIX path of (choose file with prompt "select dmg to extract:")')
else
    FILE_PATH=$(osascript -e 'POSIX path of (choose file with prompt "select pkg to extract:")')
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

# Remove previous extraction
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR" "$DMG_EXTRACT" "$APP_EXTRACT"

############################################
# 4. DMG Extraction (Non-mounting)        #
############################################

if [[ "$TYPE" == "1" ]]; then
    echo "attempting to extract dmg..."

    # Method 1: 7z
    echo "trying 7z..."
    7z x "$FILE_PATH" -o"$DMG_EXTRACT" >/dev/null 2>&1 || echo "7z failed, moving to next method"

    # Method 2: dmg2img
    echo "trying dmg2img..."
    IMG_PATH="$WORKDIR/${BASE}.img"
    dmg2img "$FILE_PATH" "$IMG_PATH" >/dev/null 2>&1 || echo "dmg2img failed"

    # Method 3: 7z on converted img
    if [ -f "$IMG_PATH" ]; then
        echo "Trying 7z on img..."
        7z x "$IMG_PATH" -o"$DMG_EXTRACT" >/dev/null 2>&1 || echo "7z on img failed"
    fi

    # Search for pkg inside extracted DMG folder
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

############################################
# 5. Expand PKG                            #
############################################

if [ -f "$PKG_PATH" ]; then
    echo "open pkg"
    rm -rf "$PKG_EXPAND"
    pkgutil --expand "$PKG_PATH" "$PKG_EXPAND" >/dev/null 2>&1 || echo "pkgutil failed, continuing"
    echo "yay"

    ########################################
    # 6. Extract Payload                    #
    ########################################

    echo "where is the fucking payload"
    PAYLOAD_PATH=$(find "$PKG_EXPAND" -type f -name "Payload" | head -n 1)

    if [ -z "$PAYLOAD_PATH" ]; then
        echo "payload found, but continuing"
    else
        echo "payload: $PAYLOAD_PATH"
        echo "open payload"
        (cd "$APP_EXTRACT" || exit
         cat "$PAYLOAD_PATH" | gunzip -dc | cpio -idmv >/dev/null 2>&1 || echo "payload extraction failed")
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
