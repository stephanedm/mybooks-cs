#!/bin/bash
# PDF audiobook player — fixed page-skipping, chunked pages
# Auto-advance after 3s only at the end of each page
# Pause waits until resume. Manual next/prev work immediately.

if [ -z "$1" ]; then
    echo "Usage: ./pdf_audiobook_fixed.sh file.pdf"
    exit 1
fi

PDF="$1"
STATE_FILE="last_page.state"
CHUNK_SIZE=20   # lines per chunk
AUTO_DELAY=3    # seconds to wait after page finish before auto-next

# Check deps
command -v pdftotext >/dev/null 2>&1 || { echo "pdftotext required (install poppler-utils)"; exit 1; }
command -v espeak-ng >/dev/null 2>&1 || { echo "espeak-ng required (install espeak-ng)"; exit 1; }

# ---- Get total pages ----
TOTAL_PAGES=$(pdfinfo "$PDF" 2>/dev/null | grep Pages | awk '{print $2}')
if [ -z "$TOTAL_PAGES" ]; then
    echo "Could not determine page count. Make sure pdfinfo is available and file exists."
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

read -p "Speed in words per minute [default 150]: " SPEED
SPEED=${SPEED:-150}

# Main loop
while [ $PAGE -le $TOTAL_PAGES ]; do
    # Ensure PAGE valid
    if [ $PAGE -lt 1 ]; then PAGE=1; fi
    if [ $PAGE -gt $TOTAL_PAGES ]; then PAGE=$TOTAL_PAGES; fi

    echo
    echo "Extracting page $PAGE..."
    pdftotext -f $PAGE -l $PAGE "$PDF" page.txt
    echo $PAGE > "$STATE_FILE"   # save progress

    TOTAL_LINES=$(wc -l < page.txt)
    START_LINE=1

    # control flags (reset per-page)
    NEXT=0
    PREV=0
    QUIT=0

    # chunk loop for this page
    while [ $START_LINE -le $TOTAL_LINES ]; do
        END_LINE=$((START_LINE + CHUNK_SIZE - 1))
        if [ $END_LINE -gt $TOTAL_LINES ]; then END_LINE=$TOTAL_LINES; fi

        sed -n "${START_LINE},${END_LINE}p" page.txt > chunk.txt
        espeak-ng -v "$VOICE" -s "$SPEED" -f chunk.txt &
        PID=$!

        echo "Reading page $PAGE (lines $START_LINE-$END_LINE)..."
        echo "[p] Pause  [r] Resume  [n] Next page  [b] Previous page  [q] Quit"
        echo "Auto-advance to next CHUNK happens if chunk ends; AUTO-ADVANCE TO NEXT PAGE happens only after last chunk of page."

        # wait loop for this chunk (manual controls allowed)
        while kill -0 $PID 2>/dev/null; do
            read -n 1 -s KEY
            if [ $? -eq 0 ]; then
                case "$KEY" in
                    p)
                        kill -STOP $PID
                        echo "Paused. Press [r] to resume, or [n]/[b]/[q] to act."
                        while true; do
                            read -n 1 -s K2
                            if [ "$K2" = "r" ]; then
                                kill -CONT $PID
                                echo "Resumed."
                                break
                            elif [ "$K2" = "n" ]; then
                                kill -KILL $PID
                                NEXT=1
                                break 2   # break out of both inner while loops for immediate action
                            elif [ "$K2" = "b" ]; then
                                kill -KILL $PID
                                PREV=1
                                break 2
                            elif [ "$K2" = "q" ]; then
                                kill -KILL $PID
                                QUIT=1
                                break 2
                            fi
                        done
                        ;;
                    r)
                        # If user presses r while not paused, just ensure continued
                        kill -CONT $PID 2>/dev/null || true
                        ;;
                    n)
                        kill -KILL $PID
                        NEXT=1
                        break 2
                        ;;
                    b)
                        kill -KILL $PID
                        PREV=1
                        break 2
                        ;;
                    q)
                        kill -KILL $PID
                        QUIT=1
                        break 2
                        ;;
                esac
            fi
        done

        # if quitting or navigation requested, break out of chunk loop
        if [ $QUIT -eq 1 ] || [ $NEXT -eq 1 ] || [ $PREV -eq 1 ]; then
            # ensure chunk process is not running
            kill -0 $PID 2>/dev/null && kill -KILL $PID 2>/dev/null || true
            break
        fi

        # finished this chunk normally -> move to next chunk
        START_LINE=$((END_LINE + 1))
        rm -f chunk.txt 2>/dev/null
    done  # end chunk loop

    # handle actions after chunk loop
    if [ $QUIT -eq 1 ]; then
        echo "Exiting. Last page saved: $PAGE"
        rm -f page.txt chunk.txt
        exit 0
    fi

    if [ $NEXT -eq 1 ]; then
        PAGE=$((PAGE + 1))
        continue
    fi

    if [ $PREV -eq 1 ]; then
        PAGE=$((PAGE - 1))
        if [ $PAGE -lt 1 ]; then PAGE=1; fi
        continue
    fi

    # If reached here, we completed all chunks for the page normally.
    # Auto-advance to next page after delay.
    echo "Page $PAGE finished. Auto-advancing to next page in ${AUTO_DELAY}s..."
    sleep $AUTO_DELAY
    PAGE=$((PAGE + 1))
done

echo "End of book. Last page saved: $PAGE"
rm -f page.txt chunk.txt
exit 0
