#!/bin/bash

# ===========================
# PDF Audiobook Player
# Auto-advance & chunk long pages
# ===========================

if [ -z "$1" ]; then
    echo "Usage: ./pdf_audiobook_chunks.sh file.pdf"
    exit 1
fi

PDF="$1"
STATE_FILE="last_page.state"
CHUNK_SIZE=20  # lines per chunk

# ---- Get total pages ----
TOTAL_PAGES=$(pdfinfo "$PDF" | grep Pages | awk '{print $2}')

if [ -z "$TOTAL_PAGES" ]; then
    echo "Could not determine page count."
    exit 1
fi

# ---- Check for saved page ----
if [ -f "$STATE_FILE" ]; then
    LAST=$(cat "$STATE_FILE")
    echo "Found saved progress: page $LAST"
    read -p "Resume from this page? (y/n): " ANSWER
    if [ "$ANSWER" = "y" ]; then
        PAGE=$LAST
    else
        PAGE=1
    fi
else
    PAGE=1
fi

echo "PDF Loaded: $PDF"
echo "Total pages: $TOTAL_PAGES"
echo

# ---- Voice Menu ----
echo "Choose a voice:"
echo "1) Male 1 (en-us+m1)"
echo "2) Male 2 (en-us+m3)"
echo "3) Female 1 (en-us+f1)"
echo "4) Female 2 (en-us+f3)"
echo "5) Whisper (en-us+whisper)"
echo "6) British Male (en-uk+m3)"
echo "7) American Male (en-us+m3)"
echo "8) African (en+mb-af1)"
echo "9) Indian (en+mb-in1)"
echo "10) Robotic (en+mb-robo)"
read -p "Select voice [1-10]: " VCHOICE

case $VCHOICE in
  1) VOICE="en-us+m1";;
  2) VOICE="en-us+m3";;
  3) VOICE="en-us+f1";;
  4) VOICE="en-us+f3";;
  5) VOICE="en-us+whisper";;
  6) VOICE="en-uk+m3";;
  7) VOICE="en-us+m3";;
  8) VOICE="en+mb-af1";;
  9) VOICE="en+mb-in1";;
  10) VOICE="en+mb-robo";;
  *) VOICE="en-us";;
esac

# ---- Speed selection ----
read -p "Speed in words per minute [default 150]: " SPEED
SPEED=${SPEED:-150}

# ==========================
#        MAIN LOOP
# ==========================
while [ $PAGE -le $TOTAL_PAGES ]; do

    echo
    echo "Extracting page $PAGE..."

    # extract specific page
    pdftotext -f $PAGE -l $PAGE "$PDF" page.txt

    # save current page
    echo $PAGE > "$STATE_FILE"

    TOTAL_LINES=$(wc -l < page.txt)
    START_LINE=1

    while [ $START_LINE -le $TOTAL_LINES ]; do
        END_LINE=$((START_LINE + CHUNK_SIZE - 1))
        if [ $END_LINE -gt $TOTAL_LINES ]; then
            END_LINE=$TOTAL_LINES
        fi

        sed -n "${START_LINE},${END_LINE}p" page.txt > chunk.txt

        # read chunk
        espeak-ng -v "$VOICE" -s "$SPEED" -f chunk.txt &
        PID=$!

        echo "Reading page $PAGE (lines $START_LINE-$END_LINE)..."
        echo "[p] Pause   [r] Resume   [n] Next Page   [b] Previous Page   [q] Quit"
        echo "Auto-advances in 3 seconds if no key pressed."

        # ---- Wait for keypress or auto-advance (3 sec) ----
        while kill -0 $PID 2>/dev/null; do
            read -t 3 -n 1 -s KEY
            if [ $? -eq 0 ]; then
                case "$KEY" in
                    p) kill -STOP $PID; echo "Paused.";;
                    r) kill -CONT $PID; echo "Resumed.";;
                    n) kill -KILL $PID; PAGE=$((PAGE + 1)); break 2;;
                    b) kill -KILL $PID; PAGE=$((PAGE - 1)); if [ $PAGE -lt 1 ]; then PAGE=1; fi; break 2;;
                    q) kill -KILL $PID; echo "Exiting. Last page saved: $PAGE"; exit 0;;
                esac
            else
                # no key pressed → auto next chunk
                kill -KILL $PID
                break
            fi
        done

        START_LINE=$((END_LINE + 1))
    done

    # after last chunk, move to next page
    PAGE=$((PAGE + 1))
done

echo "End of book. Last page saved: $PAGE"
