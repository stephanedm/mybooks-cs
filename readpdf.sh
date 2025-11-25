#!/bin/bash
# Simple PDF reader aloud script
if [ -z "$1" ]; then
    echo "Usage: ./readpdf.sh <pdf-file>"
    exit 1
fi
pdftotext "$1" - | espeak -v en-us -s 150
