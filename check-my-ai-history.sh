#!/usr/bin/env bash
# check-my-ai-history.sh
#
# Reports what your AI coding assistants have saved on this computer.
#
# It prints metadata and counts only: dates, sizes, permission modes, counts and
# configuration findings. It never prints transcript contents and never prints a
# matched secret. It does not modify transcripts or settings. It creates and
# deletes one temporary file holding a single count. It sends nothing anywhere.
# Read it before you run it.
#
#   bash check-my-ai-history.sh

set -uo pipefail

CLAUDE_DIR="$HOME/.claude/projects"
CODEX_DIR="$HOME/.codex/sessions"
SETTINGS="$HOME/.claude/settings.json"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
dim()  { printf '\033[2m%s\033[0m\n' "$1"; }

# Long steps read every transcript once, which takes a while on a big history.
# Show that something is happening rather than leaving a dead terminal.
busy_start() {
  BUSY_MSG="$1"
  if [ -t 1 ]; then
    ( frames='|/-\'; i=0
      while :; do
        i=$(( (i + 1) % 4 ))
        printf '\r\033[2m  %s %s\033[0m' "$BUSY_MSG" "${frames:$i:1}"
        sleep 0.12
      done ) &
    BUSY_PID=$!
  else
    printf '  %s\n' "$BUSY_MSG"
    BUSY_PID=""
  fi
}
busy_stop() {
  if [ -n "${BUSY_PID:-}" ]; then
    kill "$BUSY_PID" 2>/dev/null
    wait "$BUSY_PID" 2>/dev/null
    printf '\r\033[K'
  fi
  BUSY_PID=""
}
trap 'busy_stop; exit 130' INT

human_size() { du -sh "$1" 2>/dev/null | cut -f1; }

# BSD and GNU stat take different flags, and GNU `stat -f` means filesystem status,
# so it succeeds with the wrong answer instead of falling through. Branch explicitly.
case "$(uname -s)" in
  Darwin|*BSD)
    stat_mode()  { stat -f '%Lp' "$1" 2>/dev/null; }
    stat_group() { stat -f '%Sg' "$1" 2>/dev/null; }
    stat_dates() { xargs -0 stat -f '%Sm' -t '%Y-%m-%d' 2>/dev/null; }
    ;;
  *)
    stat_mode()  { stat -c '%a' "$1" 2>/dev/null; }
    stat_group() { stat -c '%G' "$1" 2>/dev/null; }
    stat_dates() { xargs -0 stat -c '%y' 2>/dev/null | cut -d' ' -f1; }
    ;;
esac

oldest_file_date() {
  find "$1" -type f -name '*.jsonl' -print0 2>/dev/null | stat_dates
}

reachable_by_others() {
  # A heuristic, not a verdict. It reads POSIX mode bits on the folders in the path
  # and on a sample of up to 50 transcripts. It does NOT read ACLs, does not look
  # below the transcript root, and cannot resolve whether a given account really
  # belongs to the group owning every folder on the way. Read a positive as "worth
  # checking" and a negative as "nothing found by mode bits".
  local target="$1" dir="$1" group_ok=1 other_ok=1 grp sampled g_readable o_readable
  grp=$(stat_group "$target")

  # the folder itself must also be listable, not just passable
  [ -z "$(find "$target" -maxdepth 0 -perm -040 2>/dev/null)" ] && group_ok=0
  [ -z "$(find "$target" -maxdepth 0 -perm -004 2>/dev/null)" ] && other_ok=0

  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    [ -z "$(find "$dir" -maxdepth 0 -perm -010 2>/dev/null)" ] && group_ok=0
    [ -z "$(find "$dir" -maxdepth 0 -perm -001 2>/dev/null)" ] && other_ok=0
    dir=$(dirname "$dir")
  done

  # traversable folders mean nothing if the files themselves are owner-only
  sampled=$(find "$target" -name '*.jsonl' 2>/dev/null | head -50)
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
    echo "not found in the folders or the sampled files"
  fi
}

report_store() {
  local label="$1" dir="$2"
  if [ ! -d "$dir" ]; then
    dim "$label: not installed"
    return
  fi
  local count size oldest helpers sessions split="${3:-}"
  busy_start "reading $label"
  count=$(find "$dir" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
  # transcripts written by helper agents live under a subagents/ folder
  helpers=$(find "$dir" -path '*/subagents/*' -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
  sessions=$(( count - helpers ))
  size=$(human_size "$dir")
  oldest=$(oldest_file_date "$dir" | sort | head -1)
  busy_stop
  bold "$label"
  printf '  transcript files      %s\n' "${count:-0}"
  if [ "${split:-}" = "split" ]; then
    printf '    sessions you had    %s\n' "${sessions:-0}"
    printf '    written by helpers  %s\n' "${helpers:-0}"
  else
    printf '    (not split: this tool records helper agents in metadata, not folders)\n'
  fi
  printf '  history folder size   %s\n' "${size:-unknown}"
  printf '  oldest one            %s\n' "${oldest:-unknown}"
  printf '  readable by another account?  %s\n' "$(reachable_by_others "$dir")"
  printf '    (mode bits on folders and up to 50 files, ACLs not checked)\n'
  echo
}

bold "==> What is saved on this computer"
echo
report_store "Claude Code" "$CLAUDE_DIR" split
report_store "Codex" "$CODEX_DIR"

bold "==> Transcript files matching credential-shaped text"
dim "    counts only, contents are never shown"
PATTERN='postgres(ql)?://[^ "]*:[^ "]*@|mysql://[^ "]*:[^ "]*@|ghp_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|JWT_SECRET|_API_KEY|_TOKEN='
for pair in "Claude Code:$CLAUDE_DIR" "Codex:$CODEX_DIR"; do
  label="${pair%%:*}"; dir="${pair#*:}"
  [ -d "$dir" ] || continue
  total=$(find "$dir" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
  out=$(mktemp)
  ( grep -rlE "$PATTERN" --include='*.jsonl' "$dir" 2>/dev/null | wc -l | tr -d ' ' > "$out" ) &
  scan_pid=$!
  if [ "${total:-0}" -gt 200 ]; then
    busy_start "$label: reading ${total} files, this can take a minute"
  else
    busy_start "$label: reading ${total:-0} files"
  fi
  wait "$scan_pid" 2>/dev/null
  busy_stop
  hits=$(cat "$out" 2>/dev/null); rm -f "$out"
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
norm = [str(r).replace(' ', '') for r in env_rules]
has_base = any(r in ('Read(./.env)', 'Read(**/.env)') for r in norm)
has_glob = any(r in ('Read(./.env.*)', 'Read(**/.env.*)') for r in norm)
if has_base and has_glob:
    print(f"  [x] deny rules cover .env and .env.* : {env_rules}")
elif env_rules:
    missing = '.env.* (so .env.local is still readable)' if has_base else '.env itself'
    print(f"  [?] partial: deny rules mention .env but not {missing}")
    print(f"      found {env_rules}. Inspect them rather than assuming coverage.")
else:
    print('  [ ] nothing stops the assistant reading your .env files')
PY
else
  echo "  [ ] no Claude Code settings file found"
fi
if [ -d "$HOME/.codex" ]; then
  mode=$(stat_mode "$HOME/.codex")
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
