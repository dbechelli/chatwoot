#!/bin/sh

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <url to zip file with favicons>. See https://github.com/fazer-ai/chatwoot/blob/main/CUSTOM_BRANDING.md for more info."
  exit 1
fi

URL="$1"
TEMP_DIR=$(mktemp -d)
ZIP_FILE="$TEMP_DIR/downloaded_favicons.zip"
EXTRACT_DIR="$TEMP_DIR/extracted_favicons"
TARGET_DIR="public"

cleanup() {
  echo "Cleaning up temporary files..."
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "Downloading zip file from $URL..."

# Use curl with redirect following. For Google Drive URLs, handle the confirmation
# token required for files that trigger the virus-scan warning page.
if curl -fsSL \
  --cookie /tmp/brand_cookies.txt \
  --cookie-jar /tmp/brand_cookies.txt \
  -o "$ZIP_FILE" \
  "$URL"; then
  # Check if what we got is actually an HTML page (Google Drive confirmation)
  MIME=$(file -b --mime-type "$ZIP_FILE" 2>/dev/null || echo "unknown")
  if [ "$MIME" = "text/html" ]; then
    echo "Got HTML confirmation page from Google Drive, extracting confirm token..."
    CONFIRM=$(grep -o 'confirm=[^&"]*' "$ZIP_FILE" | head -1 | cut -d= -f2)
    if [ -z "$CONFIRM" ]; then
      CONFIRM=$(grep -o 'uuid=[^&"]*' "$ZIP_FILE" | head -1 | cut -d= -f2)
    fi
    if [ -n "$CONFIRM" ]; then
      CONFIRM_URL="${URL}&confirm=${CONFIRM}"
      echo "Retrying download with confirmation token..."
      curl -fsSL \
        --cookie /tmp/brand_cookies.txt \
        --cookie-jar /tmp/brand_cookies.txt \
        -o "$ZIP_FILE" \
        "$CONFIRM_URL"
    else
      echo "Warning: Could not extract confirmation token. Proceeding with downloaded file."
    fi
  fi
  echo "Download successful."
else
  echo "Error: Failed to download file from $URL"
  exit 1
fi

echo "Creating extraction directory: $EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"

echo "Unzipping $ZIP_FILE to $EXTRACT_DIR..."
if unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR"; then
  echo "Unzip successful."
else
  echo "Error: Failed to unzip $ZIP_FILE"
  exit 1
fi

echo "Flattening all files from extracted archive..."
find "$EXTRACT_DIR" -type f -exec mv -f {} "$TARGET_DIR/" \;

echo "Process completed. Files placed in $TARGET_DIR/:"
find "$TARGET_DIR" -maxdepth 1 \( -name "*.svg" -o -name "*.png" -o -name "*.ico" \) | sort
