#!/usr/bin/env bash
# ANSWERS.md is complete when no ANSWER: marker is left empty.
cd "$(dirname "$0")/.."
f=ANSWERS.md
[[ -f $f ]] || { echo "ANSWERS.md is missing"; exit 1; }
empty=$(grep -nE '^\s*(Name: )?ANSWER:\s*$' "$f")
if [[ -n $empty ]]; then
  echo "These ANSWER: lines are still empty:"
  echo "$empty"
  exit 1
fi
n=$(grep -c 'ANSWER:' "$f")
[[ $n -ge 8 ]] || { echo "ANSWERS.md should have 8 ANSWER: lines (name + 7 questions), found $n"; exit 1; }
echo "All answers filled in."
