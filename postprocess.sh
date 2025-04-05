#!/usr/bin/env bash
grep -v "^%line" "$1" |
sed -e 's/MACRO_SEMICOL/;/g' \
    -e 's/MACRO_PERCENT/%/g' \
    -e 's/MACRO_HASH/#/g' \
    -e 's/&nbsp;/ /g'
