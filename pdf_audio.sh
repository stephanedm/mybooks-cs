#!/bin/bash

# ===========================
# PDF Audiobook Player (Pages)
# ===========================

if [ -z "$1" ]; then
    echo "Usage: ./pdf_audiobook.sh file.pdf"
    exit 1
fi

PDF="$1"

# ---- Get total pages ----
TOTAL_PAGES=$(pdfinfo "$PDF" | grep Pages | awk '{print $2}')

if [ -z "$TOTAL_PAGES" ]; then
    echo "Could not determine page count."
    exit 1
fi

echo "PDF Loaded: $PDF"
echo "Total pages: $TOTAL_PAGES"
echo

# ---- Choose voice and speed ----
echo -n "Voice (default en-us): "
read VOICE
VOICE=${VOICE:-en-us}

echo -n "Speed (default 150): "
read SPEED
SPEED=${SPEED:-150}

PAGE=1  # start at page 1

# ==========================
#        MAIN LOOP
# ==========================

while true; do

    echo
    echo "Extracting page $PAGE..."

    # extract specific page
    pdftotext -f $PAGE -l $PAGE "$PDF" page.txt

    # read page aloud
    espeak-ng -v "$VOICE" -s "$SPEED" -f page.txt &
    PID=$!

    echo "Reading page $PAGE..."
    echo "[p] Pause   [r] Resume   [n] Next   [b] Back   [q] Quit"

    # ---- Wait for keypress ----
    while kill -0 $PID 2>/dev/null; do
        read -n 1 -s KEY

        case "$KEY" in
            p)
                kill -STOP $PID
                echo "Paused."
                ;;
            r)
                kill -CONT $PID
                echo "Resumed."
                ;;
            n)
                kill -KILL $PID
                PAGE=$((PAGE + 1))
                if [ $PAGE -gt $TOTAL_PAGES ]; then
                    PAGE=$TOTAL_PAGES
                    echo "End of book."
                fi
                break
                ;;
            b)
                kill -KILL $PID
                PAGE=$((PAGE - 1))
                if [ $PAGE -lt 1 ]; then
                    PAGE=1
                fi
                break
                ;;
            q)
                kill -KILL $PID
                echo "Goodbye!"
                exit 0
                ;;
        esac
    done
done
