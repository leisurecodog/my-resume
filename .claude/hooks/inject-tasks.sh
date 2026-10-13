#!/usr/bin/env bash
# SessionStart hook: inject tasks/handoff.md and tasks/progress.md as context.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
out=""
for f in tasks/handoff.md tasks/progress.md; do
  [ -f "$f" ] && out+="## $f"$'\n'"$(cat "$f")"$'\n\n'
done
[ -z "$out" ] && exit 0
jq -n --arg c "$out" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
