#!/bin/bash

# Constants
GITHUB_URL="https://raw.githubusercontent.com/rramesh/mp3converter/main/mp3converter"
INSTALL_DIR="$HOME/.mp3c"
SCRIPT_NAME="mp3converter"

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

echo -e "\nInstallation complete!"
echo -e "\nTo complete installation, either:"
echo "1. Open a new terminal window, or"
echo "2. Run this command in your current terminal:"
echo "   source $RC_FILE"
echo -e "\nOnce done, you can run 'mp3converter --help' to see usage instructions."
