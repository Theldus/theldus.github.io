#!/usr/bin/env bash

# Function to HTML escape content
html_escape() {
	sed -e 's/&/\&ampMACRO_SEMICOL/g' \
		-e 's/</\&ltMACRO_SEMICOL/g' \
		-e 's/>/\&gtMACRO_SEMICOL/g' \
		-e 's/%/MACRO_PERCENT/g' \
		-e 's/#/MACRO_HASH/g' \
		-e 's/;/MACRO_SEMICOL/g' \
		-e 's/ /\&nbspMACRO_SEMICOL/g' \
		-e 's/\t/\&nbspMACRO_SEMICOL\&nbspMACRO_SEMICOL\&nbspMACRO_SEMICOL\&nbspMACRO_SEMICOL/g'
}

# Function to process BC_FILE macro
process_bc_file() {
	local line="$1"
	local src_dir="$2"
	local tmp_file="$3"

	# Extract filename from BC_FILE() macro
	local filename=$(echo "$line" | sed -n 's/BC_FILE(\(.*\))/\1/p')
	# Determine the root directory (one level up from src_dir)
	local root_dir=$(dirname "$src_dir")
	# Construct path to the file (relative to root directory)
	file_to_include="${root_dir}/${filename}"

	# Process the included file with consistent escaping
	echo "BC_S"
	if [[ -f "$file_to_include" ]]; then
		cat "$file_to_include" | html_escape
	else
		echo "File not found: $filename (looking in ${file_to_include})"
	fi

	# Use the original filename for the caption (already relative to root)
	echo "BC_E_CAPTION($filename)"
}

# Main function to process the file
process_file() {
	local input_file="$1"
	local output_file="$2"
	local src_dir="${SRC_DIR:-src_posts/}"
	local in_code_block=0

	# Process each line
	while IFS= read -r line; do
		# Check for BC_FILE macro
		if [[ "$line" =~ BC_FILE\(.*\) ]]; then
			process_bc_file "$line" "$src_dir" "$TMPDIR/included_file.txt"
			continue
		fi

		# Check for code block markers
		if [[ "$line" == "BC_S" ]]; then
			in_code_block=1
			echo "$line"
			continue
		elif [[ "$line" == "BC_E"* ]]; then
			in_code_block=0
			echo "$line"
			continue
		fi

		# Process content based on whether we're in a code block
		if [[ $in_code_block -eq 1 ]]; then
			echo "$line" | html_escape
		else
			echo "$line"
		fi
	done < "$input_file" > "$output_file"
}

# Temporary directory for intermediate files
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Check for input and output files
if [[ $# -lt 2 ]]; then
	echo "Usage: $0 input_file output_file"
	exit 1
fi

input_file="$1"
output_file="$2"

# Process the file
process_file "$input_file" "$output_file"
