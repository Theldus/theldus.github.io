#!/usr/bin/env python

#
# Theldus's blog src code
# This is free and unencumbered software released into the public domain.
#

import os
import sys
import re

# Define NASM keywords that need special handling
NASM_KEYWORDS = [
	"CPU",
	"at",
	"static",
]

#
# Replace NASM keywords with their _KEYWORD versions
#
def replace_keywords(content):
	result = content
	for keyword in NASM_KEYWORDS:
		# Use word boundaries to avoid partial matches
		pattern = r'\b' + re.escape(keyword) + r'\b'
		result = re.sub(pattern, keyword + '_KEYWORD', result)
	return result

#
# Escape HTML characters and handle special characters for NASM
#
def html_escape(content):
	result = content
	result = result.replace('&', '&ampMACRO_SEMICOL')
	result = result.replace('<', '&ltMACRO_SEMICOL')
	result = result.replace('>', '&gtMACRO_SEMICOL')
	result = result.replace('%', 'MACRO_PERCENT')
	result = result.replace('#', 'MACRO_HASH')
	result = result.replace(';', 'MACRO_SEMICOL')
	result = result.replace(' ', '&nbspMACRO_SEMICOL')
	result = result.replace('\t', 'MACRO_TAB')
	return result

#
# Process BC_FILE macro by extracting and including file content
#
def process_bc_file(line, src_dir):
	result = []

	# Extract filename from BC_FILE() macro
	match = re.search(r'BC_FILE\((.*?)\)', line)
	if not match:
		result.append("Error: Invalid BC_FILE format")
		return result

	filename = match.group(1)
	root_dir = os.path.dirname(src_dir)
	file_to_include = os.path.join(root_dir, filename)

	result.append("BC_S")

	# Process the included file
	if os.path.isfile(file_to_include):
		try:
			f = open(file_to_include, 'r')
			content = f.read()
			f.close()

			content = replace_keywords(content)
			content = html_escape(content)

			for line in content.splitlines():
				result.append(line)
		except:
			result.append("Error: Could not read file: " + filename)
	else:
		result.append("File not found: " + filename + " (looking in " + file_to_include + ")")

	result.append("BC_E_CAPTION(" + filename + ")")
	return result

#
# Process the entire file, handling code blocks and keywords
#
def process_file(input_file, output_file, src_dir):
	try:
		f = open(input_file, 'r')
		content = f.read()
		f.close()
	except:
		sys.stderr.write("Error: Could not read input file: " + input_file + "\n")
		return 1

	# First replace keywords throughout the entire file
	content = replace_keywords(content)
	lines = content.splitlines()

	result = []
	in_code_block = False

	for line in lines:
		# Check for BC_FILE macro
		if "BC_FILE(" in line:
			bc_result = process_bc_file(line, src_dir)
			for bc_line in bc_result:
				result.append(bc_line)
			continue

		# Check for code block markers
		if line == "BC_S":
			in_code_block = True
			result.append(line)
			continue
		elif line.startswith("BC_E"):
			in_code_block = False
			result.append(line)
			continue

		# Process content based on whether we're in a code block
		if in_code_block:
			result.append(html_escape(line))
		else:
			result.append(line)

	# Write output
	try:
		f = open(output_file, 'w')
		for line in result:
			f.write(line + '\n')
		f.close()
	except:
		sys.stderr.write("Error: Could not write to output file: " + output_file + "\n")
		return 1

	return 0

#
# Restore original characters and keywords after NASM processing
#
def postprocess_file(input_file, output_file=None):
	try:
		f = open(input_file, 'r')
		lines = f.readlines()
		f.close()
	except:
		sys.stderr.write("Error: Could not read input file: " + input_file + "\n")
		return 1

	# Remove lines starting with %line
	filtered_lines = []
	for line in lines:
		if not line.startswith('%line'):
			filtered_lines.append(line)

	content = ''.join(filtered_lines)

	# Handle standard replacements
	content = content.replace('MACRO_SEMICOL', ';')
	content = content.replace('MACRO_PERCENT', '%')
	content = content.replace('MACRO_HASH', '#')
	content = content.replace('&nbsp;', ' ')
	content = content.replace('MACRO_TAB', '\t');

	# Restore all NASM keywords
	for keyword in NASM_KEYWORDS:
		content = content.replace(keyword + '_KEYWORD', keyword)

	# Write output
	if output_file:
		try:
			f = open(output_file, 'w')
			f.write(content)
			f.close()
		except:
			sys.stderr.write("Error: Could not write to output file: " + output_file + "\n")
			return 1
	else:
		sys.stdout.write(content)

	return 0

#
# Main function to handle command-line arguments
#
def main():
	if len(sys.argv) < 3:
		print(sys.argv[0] + " preprocess input_file output_file")
		print(sys.argv[0] + " postprocess input_file [output_file]")
		return 1

	mode = sys.argv[1]
	input_file = sys.argv[2]

	if mode == "preprocess":
		if len(sys.argv) < 4:
			sys.stderr.write("Error: Output file required for preprocess mode\n")
			return 1
		output_file = sys.argv[3]
		src_dir = os.environ.get('SRC_DIR', 'src_posts/')
		return process_file(input_file, output_file, src_dir)
	elif mode == "postprocess":
		output_file = None
		if len(sys.argv) >= 4:
			output_file = sys.argv[3]
		return postprocess_file(input_file, output_file)
	else:
		sys.stderr.write("Error: Invalid mode. Use 'preprocess' or 'postprocess'\n")
		return 1

if __name__ == "__main__":
	sys.exit(main())
