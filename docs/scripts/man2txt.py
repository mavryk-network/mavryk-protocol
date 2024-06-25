#!/usr/bin/env python3
# Convert man pages to simple text by removing formatting directives
<<<<<<< .merge_file_GKviWt

# Currently, only bold characters are replaced: x^Hx -> x

import re
import fileinput

for line in fileinput.input():
    line = line.rstrip('\n')
    # get rid of the overwritten letters
    line = re.sub(r'.[\b]', '', line)
    # protect double dashes from being interpreted as a long dash
    line = re.sub(r'--', r'-\-', line)
=======
# (e.g., bold characters are replaced: x^Hx -> x)
# With option -r, further make output compatible with RST syntax

import re
import fileinput
import argparse

parser = argparse.ArgumentParser()
parser.add_argument(
    "-r",
    "--RST",
    action="store_true",
    help="make output compatible with ReS",
)
parser.add_argument(
    'files',
    metavar='FILE',
    nargs='*',
    help='files to read, if empty, stdin is used',
)
args = parser.parse_args()

for line in fileinput.input(files=args.files):
    line = line.rstrip('\n')
    # get rid of the overwritten letters
    line = re.sub(r'.[\b]', '', line)
    if args.RST:
        # protect double dashes from being interpreted as a long dash
        line = re.sub(r'--', r'-\-', line)
>>>>>>> .merge_file_B7bNo8
    print(line)
