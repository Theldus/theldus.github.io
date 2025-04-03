#!/usr/bin/env bash

#
# Theldus's blog
# This is free and unencumbered software released into the public domain.
#

# Define constants
SRC_POSTS=src_posts
INDEX=${SRC_POSTS}/index.asm

# Create the header of the index file
cat<<EOF> ${INDEX}
%include "macros.inc"
%include "header.inc"
S My posts
UL_CSS("list-link-home")
EOF

# Create an array to store posts with dates for sorting
declare -a posts_array

# Process each post file
for f in "$@"; do
    post="${SRC_POSTS}/${f}.asm"

    # Skip if file doesn't exist
    if [ ! -f "$post" ]; then
        echo "Warning: file '$f' does not exist!"
        continue
    fi

    # Extract title and date
    POST_TITLE=$(grep "SET_POST_TITLE" -m 1 "${post}" | cut -d' ' -f2-)
    POST_DATE=$( grep "SET_POST_DATES" -m 1 "${post}" | cut -d' ' -f2 | tr -d ',')

    # Validate title and date
    if [ -z "${POST_TITLE}" ] || [ -z "${POST_DATE}" ]; then
        echo "Warning: file '$f' does not have title and/or date!"
        continue
    fi

    # Add to array with date as sort key
    posts_array+=("${POST_DATE}|${f}|${POST_TITLE}")
done

# Sort posts by date in reverse order (newest first)
IFS=$'\n'
sorted_posts=($(sort -r <<<"${posts_array[*]}"))
unset IFS

# Generate the list of posts in sorted order
for post in "${sorted_posts[@]}"; do
    # Split the fields
    IFS='|' read -r date file title <<< "$post"

    # Write to index file
cat<<EOF>> ${INDEX}
LI_S
<a href="/posts/${file}" class="link-home">[${date}]: ${title}</a>
LI_E
EOF

done

# Add the footer
cat<<EOF>> ${INDEX}
UL_E
%include "footer.inc"
EOF

echo "Generated index.asm with ${#sorted_posts[@]} posts."
