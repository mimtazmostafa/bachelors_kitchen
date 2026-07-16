#!/usr/bin/env python3
"""Replace matchPercent with matchLabel in ai_chef_screen.dart."""
PATH = r'd:\grade tracker\bachelors_kitchen\lib\screens\ai_chef_screen.dart'

with open(PATH, 'rb') as f:
    data = f.read()

# Pattern: "matchPercent: _results[i].score," within the RecipeCard call
old = b"matchPercent: _results[i].score,"
new = b"matchLabel: t.matchLabel(_results[i].score),"
n = data.count(old)
print(f"Occurrences of matchPercent pattern: {n}")
if n != 1:
    raise SystemExit(f"Expected exactly 1 occurrence, got {n}")
data = data.replace(old, new)

with open(PATH, 'wb') as f:
    f.write(data)
print("Done.")