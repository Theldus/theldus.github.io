#!/bin/bash

# Function to HTML escape content
html_escape() {
    echo "$1" | sed -e 's/&/\&ampMACRO_SEMICOL/g' \
                    -e 's/</\&ltMACRO_SEMICOL/g' \
                    -e 's/>/\&gtMACRO_SEMICOL/g' \
                    -e 's/%/MACRO_PERCENT/g' \
                    -e 's/#/MACRO_HASH/g' \
                    -e 's/;/MACRO_SEMICOL/g'
}

# Temporary directory for intermediate files
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Input and output files
input_file="$1"
output_file="$2"

# Source directory (assuming it's passed as an environment variable)
SRC_DIR="${SRC_DIR:-src_posts/}"

# Temporary processing file
processed_file="$TMPDIR/processed.txt"

# Process the input file
awk -v src_dir="$SRC_DIR" '
BEGIN {
    in_code_block = 0
    in_file_block = 0
}

# BC_FILE handling
/BC_FILE\(.*\)/ {
    filename = gensub(/BC_FILE\((.*)\)/, "\\1", "g")

    # Check if it"s an absolute path
    if (filename ~ /^\//) {
        file_to_include = filename
    } else {
        # Construct relative path
        file_to_include = src_dir "/" filename
    }

    system("cat \"" file_to_include "\" | sed -e \"s/&/\\&amp;/g\" -e \"s/</\\&lt;/g\" -e \"s/>/\\&gt;/g\" -e \"s/#/MACRO_HASH /g\" > \"'"$TMPDIR"'/included_file.txt\"")
    print "BC_S"
    system("cat \"'"$TMPDIR"'/included_file.txt\"")
    print "BC_E_CAPTION(" filename ")"
    next
}

# BC_S marker
/BC_S/ {
    in_code_block = 1
    print
    next
}

# BC_E marker
/BC_E/ {
    in_code_block = 0
    print
    next
}

# Inside code block: escape HTML and handle #
in_code_block {
    # Escape HTML and handle #
    gsub(/&/, "\\&ampMACRO_SEMICOL")
    gsub(/</, "\\&ltMACRO_SEMICOL")
    gsub(/>/, "\\&gtMACRO_SEMICOL")
    gsub(/%/, "MACRO_PERCENT]")
    gsub(/#/, "MACRO_HASH")
    gsub(/;/, "MACRO_SEMICOL")
    print
    next
}

# Default: pass through
{
    print
}
' "$input_file" > "$processed_file"

# Final output
cat "$processed_file" > "$output_file"
