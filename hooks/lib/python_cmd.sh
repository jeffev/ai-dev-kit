#!/usr/bin/env bash
# Detect the working Python 3 command.
# On Windows/Git Bash, python3 may be a Microsoft Store stub that shows
# a redirect prompt instead of running. Fall back to `python` if so.

_detect_python() {
  if python3 -c "import sys; sys.exit(0)" 2>/dev/null; then
    echo "python3"
  elif python -c "import sys; sys.exit(0)" 2>/dev/null; then
    echo "python"
  else
    echo ""
  fi
}

PYTHON_CMD="$(_detect_python)"
