#!/bin/bash

# Constants
GITHUB_URL="https://raw.githubusercontent.com/rramesh/mp3converter/main/mp3converter.sh"
INSTALL_DIR="$HOME/.mp3c"
SCRIPT_NAME="mp3converter.sh"

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Download script
echo "Downloading mp3converter..."
curl -s -o "$INSTALL_DIR/$SCRIPT_NAME" "$GITHUB_URL"

if [ $? -ne 0 ]; then
    echo "Error: Failed to download script"
    exit 1
fi

# Make executable
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Detect OS and shell
case "$OSTYPE" in
    darwin*)
        # On macOS, check for zsh first as it's the default
        if [[ "$SHELL" == *"zsh"* ]]; then
            RC_FILE="$HOME/.zshrc"
        elif [[ "$SHELL" == *"bash"* ]]; then
            RC_FILE="$HOME/.bash_profile"
        else
            # Default to zsh on modern macOS
            RC_FILE="$HOME/.zshrc"
        fi
        ;;
    linux*)
        if [ -n "$ZSH_VERSION" ]; then
            RC_FILE="$HOME/.zshrc"
        else
            RC_FILE="$HOME/.bashrc"
        fi
        ;;
    *)
        echo "Unsupported OS: $OSTYPE"
        exit 1
        ;;
esac

# Add to PATH if not already present
if ! grep -q "export PATH=\"\$HOME/.mp3c:\$PATH\"" "$RC_FILE"; then
    echo '' >> "$RC_FILE"
    echo '# Added by mp3converter installer' >> "$RC_FILE"
    echo 'export PATH="$HOME/.mp3c:$PATH"' >> "$RC_FILE"
    
    echo "Added $INSTALL_DIR to PATH in $RC_FILE"
else
    echo "$INSTALL_DIR already in PATH"
fi

# Source RC file
echo "Reloading shell configuration..."
source "$RC_FILE" 2>/dev/null || . "$RC_FILE"

echo -e "\nInstallation complete!"
echo "Running help to show usage..."
echo "----------------------------"
"$INSTALL_DIR/$SCRIPT_NAME" --help

echo -e "\nYou may need to restart your terminal or run:"
echo "source $RC_FILE"
