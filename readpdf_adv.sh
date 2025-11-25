#!/bin/bash
# Advanced PDF Reader Script for Kali Linux

# Check for at least one PDF
if [ $# -lt 1 ]; then
    echo "Usage: ./readpdf_advanced.sh <pdf-file1> [pdf-file2 ...]"
    exit 1
fi

# Ask for voice and speed
echo "Enter voice (e.g., en-us, en-uk, en-us+f3, en-us+m3): "
read VOICE
VOICE=${VOICE:-en-us}  # default if empty

echo "Enter speed in words per minute (default 150): "
read SPEED
SPEED=${SPEED:-150}

# Loop through all provided PDFs
for PDF in "$@"
do
    if [ ! -f "$PDF" ]; then
        echo "File not found: $PDF"
        continue
    fi

    echo "Reading PDF: $PDF ..."
    pdftotext "$PDF" - | espeak-ng -v "$VOICE" -s "$SPEED"
done

echo "All PDFs read."
