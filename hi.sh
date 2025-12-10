#!/bin/bash

echo "attwmcf?"
echo

############################################
#   0. Homebrew (user-level) + 7z checks   #
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

    # detection fallback
    if [ -x "$HOME/.linuxbrew/bin/brew" ]; then
        export PATH="$HOME/.linuxbrew/bin:$PATH"
    fi
    if [ -x "/opt/homebrew/bin/brew" ]; then
        export PATH="/opt/homebrew/bin:$PATH"
    fi
fi

# Re-check brew
if ! command -v brew &>/dev/null; then
    echo "homebrew installation failed"
    exit 1
fi

# Install p7zip if needed
if ! command -v 7z &>/dev/null; then
    echo "not found specific file thing"
    brew install p7zip || { echo "failed to install p7zip"; exit 1; }
fi

############################################
#      1. Extraction Type Selection        #
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
#   2. Ask for File + Output Folder GUI    #
############################################

if [[ "$TYPE" == "1" ]]; then
    FILE_PATH=$(osascript -e 'POSIX path of (choose file with prompt "select dmg to extract:")')
else
    FILE_PATH=$(osascript -e 'POSIX path of (choose file with prompt "select pkg to extract:")')
fi

OUTDIR=$(osascript -e 'POSIX path of (choose folder with prompt "where do i save the files at:")')

############################################
#        3. Setup Working Directories      #
############################################

BASE=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
WORKDIR="$OUTDIR/${BASE}_extracted"
DMG_EXTRACT="$WORKDIR/dmg_extracted"
PKG_EXPAND="$WORKDIR/pkg_expanded"
APP_EXTRACT="$WORKDIR/app_extracted"

mkdir -p "$WORKDIR" "$APP_EXTRACT"

############################################
#              4. DMG Extract              #
############################################

if [[ "$TYPE" == "1" ]]; then
    mkdir -p "$DMG_EXTRACT" "$PKG_EXPAND"
    echo "extracting dmg"

    7z x "$FILE_PATH" -o"$DMG_EXTRACT" >/dev/null || {
        echo "no the extraction didnt work and its all your fault (no)"
        rm -rf "$WORKDIR"
        exit 1
    }

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

############################################
#             5. Expand PKG                #
############################################

mkdir -p "$PKG_EXPAND"
echo "open pkg"

pkgutil --expand "$PKG_PATH" "$PKG_EXPAND" || {
    echo "pkgutil failed"
    rm -rf "$WORKDIR"
    exit 1
}

echo "yay"

############################################
#            6. Extract Payload            #
############################################

echo "where is the fucking payload"

PAYLOAD_PATH=$(find "$PKG_EXPAND" -type f -name "Payload" | head -n 1)

if [ -z "$PAYLOAD_PATH" ]; then
    echo "payload found"
    rm -rf "$WORKDIR"
    exit 1
fi

echo "payload: $PAYLOAD_PATH"
echo "open payload"

(
    cd "$APP_EXTRACT" || exit
    cat "$PAYLOAD_PATH" | gunzip -dc | cpio -idmv
)

############################################
#                 DONE                     #
############################################

echo "ok its done"
echo " "
echo "dmg extracted to        $DMG_EXTRACT"
echo "pkg expanded to         $PKG_EXPAND"
echo "app files extracted to  $APP_EXTRACT"

rm -- "$0"
# yeah zero fucking dollars thats what you get from running the script
