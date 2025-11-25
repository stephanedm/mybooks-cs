#!/bin/bash
# Mini PDF Audiobook Player for Kali

if [ $# -lt 1 ]; then
    echo "Usage: ./readpdf_player.sh <pdf-file1> [pdf-file2 ...]"
    exit 1
fi

# Ask for voice and speed
echo "Enter voice (e.g., en-us, en-uk, en-us+f3, en-us+m3): "
read VOICE
VOICE=${VOICE:-en-us}

echo "Enter speed in words per minute (default 150): "
read SPEED
SPEED=${SPEED:-150}

for PDF in "$@"; do
    if [ ! -f "$PDF" ]; then
        echo "File not found: $PDF"
        continue
    fi

    echo "Starting PDF: $PDF"
    # Convert PDF to text
    TEXT=$(pdftotext "$PDF" -)

    # Save text to temp file
    TMPFILE=$(mktemp)
    echo "$TEXT" > "$TMPFILE"

    # Play the text in the background
    espeak-ng -v "$VOICE" -s "$SPEED" -f "$TMPFILE" &
    PID=$!

    echo "Controls: [p] Pause  [r] Resume  [n] Next PDF  [q] Quit"
    while kill -0 $PID 2>/dev/null; do
        read -n 1 -s key
        case "$key" in
            p)
                kill -STOP $PID
                echo "Paused..."
                ;;
            r)
                kill -CONT $PID
                echo "Resumed..."
                ;;
            n)
                kill -KILL $PID
                echo "Skipping to next PDF..."
                break
                ;;
            q)
                kill -KILL $PID
                echo "Exiting..."
                exit 0
                ;;
        esac
    done

    rm "$TMPFILE"
done

echo "All PDFs finished."
