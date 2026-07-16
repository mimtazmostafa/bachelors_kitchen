#!/usr/bin/env python3
"""Find the line with Chef's pick."""
PATH = r'd:\grade tracker\bachelors_kitchen\lib\screens\ai_chef_screen.dart'
with open(PATH, 'rb') as f:
    data = f.read()
import re
for m in re.finditer(rb"isBn \? '[^']*' : \"[^\"]*\"", data):
    idx = m.start()
    line_no = data[:idx].count(b'\n') + 1
    line_start = data.rfind(b'\n', 0, idx) + 1
    line_end = data.find(b'\n', m.end())
    if line_end == -1: line_end = len(data)
    print(f"Line {line_no}: {data[line_start:line_end].decode('utf-8', 'replace')}")
    print(f"  Hex: {data[idx:m.end()].hex()}")
    print()