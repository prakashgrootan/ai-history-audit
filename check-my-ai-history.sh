#!/usr/bin/env bash
# check-my-ai-history.sh
#
# Reports what your AI coding assistants have saved on this computer.
#
# It prints COUNTS ONLY. It never prints the contents of a conversation, it
# writes nothing, and it sends nothing anywhere. Read it before you run it.
#
#   bash check-my-ai-history.sh

set -uo pipefail

CLAUDE_DIR="$HOME/.claude/projects"
CODEX_DIR="$HOME/.codex/sessions"
SETTINGS="$HOME/.claude/settings.json"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
dim()  { printf '\033[2m%s\033[0m\n' "$1"; }

human_size() { du -sh "$1" 2>/dev/null | cut -f1; }

oldest_file_date() {
  # macOS stat first, then GNU stat
  find "$1" -type f -name '*.jsonl' -print0 2>/dev/null \
    | xargs -0 stat -f '%Sm' -t '%Y-%m-%d' 2>/dev/null \
    || find "$1" -type f -name '*.jsonl' -printf '%TY-%Tm-%Td\n' 2>/dev/null
}

reachable_by_others() {
  # A heuristic, not a verdict. It reads POSIX mode bits on the folders in the path
  # and on a sample of the transcripts themselves. It does NOT evaluate ACLs, other
  # security layers, or whether a particular account is really a member of the group
  # that owns every folder along the way. Treat a "yes" as "worth checking", and a
  # "no" as "not reachable by mode bits alone".
  local target="$1" dir="$1" group_ok=1 other_ok=1 grp
  grp=$(stat -f '%Sg' "$target" 2>/dev/null || stat -c '%G' "$target" 2>/dev/null)

  # the folder itself must be listable, not merely passable
  [ -z "$(find "$target" -maxdepth 0 -perm -040 2>/dev/null)" ] && group_ok=0
  [ -z "$(find "$target" -maxdepth 0 -perm -004 2>/dev/null)" ] && other_ok=0

  # every folder from here up to / must let an outsider pass through
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    [ -z "$(find "$dir" -maxdepth 0 -perm -010 2>/dev/null)" ] && group_ok=0
    [ -z "$(find "$dir" -maxdepth 0 -perm -001 2>/dev/null)" ] && other_ok=0
    dir=$(dirname "$dir")
  done

  # traversable folders mean nothing if the files themselves are owner-only, so sample
  local sampled g_readable o_readable
  sampled=$(find "$target" -name '*.jsonl' -maxdepth 4 2>/dev/null | head -50)
  if [ -n "$sampled" ]; then
    g_readable=$(printf '%s\n' "$sampled" | while read -r f; do
      [ -n "$(find "$f" -maxdepth 0 -perm -040 2>/dev/null)" ] && echo x; done | wc -l | tr -d ' ')
    o_readable=$(printf '%s\n' "$sampled" | while read -r f; do
      [ -n "$(find "$f" -maxdepth 0 -perm -004 2>/dev/null)" ] && echo x; done | wc -l | tr -d ' ')
    [ "${g_readable:-0}" -eq 0 ] && group_ok=0
    [ "${o_readable:-0}" -eq 0 ] && other_ok=0
  fi

  if [ "$other_ok" -eq 1 ]; then
    echo "probably, by any account on this computer"
  elif [ "$group_ok" -eq 1 ]; then
    echo "probably, by any account in group $grp"
  else
    echo "not by folder and file permissions"
  fi
}

report_store() {
  local label="$1" dir="$2"
  if [ ! -d "$dir" ]; then
    dim "$label: not installed"
    return
  fi
  local count size oldest helpers sessions
  count=$(find "$dir" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
  # transcripts written by helper agents live under a subagents/ folder
  helpers=$(find "$dir" -path '*/subagents/*' -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
  sessions=$(( count - helpers ))
  size=$(human_size "$dir")
  oldest=$(oldest_file_date "$dir" | sort | head -1)
  bold "$label"
  printf '  transcript files      %s\n' "${count:-0}"
  printf '    sessions you had    %s\n' "${sessions:-0}"
  printf '    written by helpers  %s\n' "${helpers:-0}"
  printf '  space used            %s\n' "${size:-unknown}"
  printf '  oldest one            %s\n' "${oldest:-unknown}"
  printf '  readable by another account?  %s\n' "$(reachable_by_others "$dir")"
  printf '    (mode bits only, ACLs not checked)\n'
  echo
}

bold "==> What is saved on this computer"
echo
report_store "Claude Code" "$CLAUDE_DIR"
report_store "Codex" "$CODEX_DIR"

bold "==> Transcript files matching credential-shaped text"
dim "    counts only, contents are never shown"
PATTERN='postgres(ql)?://[^ "]*:[^ "]*@|mysql://[^ "]*:[^ "]*@|ghp_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|JWT_SECRET|_API_KEY|_TOKEN='
for pair in "Claude Code:$CLAUDE_DIR" "Codex:$CODEX_DIR"; do
  label="${pair%%:*}"; dir="${pair#*:}"
  [ -d "$dir" ] || continue
  hits=$(grep -rlE "$PATTERN" --include='*.jsonl' "$dir" 2>/dev/null | wc -l | tr -d ' ')
  total=$(find "$dir" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
  printf '  %-14s %s of %s transcript files\n' "$label" "${hits:-0}" "${total:-0}"
done
echo
dim "    a match is not proof of a live secret. Docs, examples and old values match too."
echo

bold "==> Settings worth changing"
echo
if [ -f "$SETTINGS" ] && command -v python3 >/dev/null; then
  python3 - "$SETTINGS" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"  could not read settings ({e})"); raise SystemExit
days = d.get('cleanupPeriodDays')
if days is None:
    print("  [ ] cleanupPeriodDays is not set, so the tool's own default applies")
elif days > 90:
    print(f"  [ ] cleanupPeriodDays is {days} days, which is extended retention. The documented default is 30.")
else:
    print(f"  [x] cleanupPeriodDays is {days} days")
deny = ((d.get('permissions') or {}).get('deny')) or []
env_rules = [r for r in deny if '.env' in str(r)]
if env_rules:
    print(f"  [x] the assistant is blocked from reading env files: {env_rules}")
else:
    print('  [ ] nothing stops the assistant reading your .env files')
PY
else
  echo "  [ ] no Claude Code settings file found"
fi
if [ -d "$HOME/.codex" ]; then
  mode=$(stat -f '%Lp' "$HOME/.codex" 2>/dev/null || stat -c '%a' "$HOME/.codex" 2>/dev/null)
  case "$mode" in
    700) echo "  [x] the Codex folder is closed to other accounts" ;;
    *)   echo "  [ ] the Codex folder is mode $mode. Close it with: chmod 700 ~/.codex ~/.codex/sessions" ;;
  esac
fi
if command -v fdesetup >/dev/null; then
  fdesetup status 2>/dev/null | grep -q On \
    && echo "  [x] disk encryption is on" \
    || echo "  [ ] disk encryption looks off. Turn on FileVault."
fi
echo
dim "Two more that no script can check for you:"
dim "  pin the small tools that read this history, instead of fetching the newest each run"
dim "  keep passwords and keys out of the conversation in the first place"
