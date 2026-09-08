# ai-history-audit

Your AI coding assistant keeps a plain-text record of your work with it: the files it opened,
the commands it ran, and what those printed. Claude Code's own documentation says so, and adds
that these files are not encrypted and that operating system file permissions are the only
thing protecting them.

This script tells you what is on your own machine.

## What it does

Read [the script](check-my-ai-history.sh) on this page first, then download a tagged release
and read the copy you actually downloaded before running it:

```bash
cd ~/Downloads
curl -fsSLo check-my-ai-history.sh https://raw.githubusercontent.com/prakashgrootan/ai-history-audit/v1.0.5/check-my-ai-history.sh
cat check-my-ai-history.sh          # or: open -e check-my-ai-history.sh
bash check-my-ai-history.sh
rm check-my-ai-history.sh
```

The URL names the `v1.0.5` tag rather than `main`, so it will not change when the main branch
does. A tag is versioned rather than immutable; for genuine pinning, use a full commit hash in
place of the tag. `cat` prints and returns; use `less` if you prefer a pager,
and press `q` to leave it.

Do not pipe this, or any script, from the internet straight into your shell.

It reports, for Claude Code and Codex:

- how many transcript files exist. For Claude Code these are split into top-level files and
  transcripts written by helper agents, because that tool separates them by folder. Codex is
  reported as one number, since it records agent origin in session metadata instead
- the oldest file's modification date, which is a rough age rather than a start date, since
  resuming a session updates it, and how much disk the history folder uses
- whether another account on the machine looks able to reach them. This is a mode-bit
  heuristic: it reads POSIX permissions on the folders in the path and on a sample of up to 50
  transcripts. It does not read ACLs, does not look below the transcript root, and cannot tell
  whether a particular account belongs to the group owning each folder. A positive means worth
  checking; a negative means nothing was found by mode bits alone
- how many files contain credential-shaped text
- what it can see of the recommended settings, reported as observations rather than verdicts.
  It reads the user settings file only, so it cannot tell you whether a project, local or
  managed setting covers you: run `/status` for the loaded sources and `/permissions` for the
  resolved rules. It also cannot check sandboxing, how you pin your tools, or how you handle
  secrets

## What it deliberately does not do

- **It never prints the contents of a transcript.** It prints metadata and counts only: dates,
  sizes, permission modes, counts and configuration findings.
- **It never prints a matched secret.** For credential-shaped text it reports how many files
  matched, never what matched or where.
- **It sends nothing anywhere.** No network calls at all.
- **It does not modify transcripts or settings.** It creates and deletes one temporary file
  holding a single count. Any fix it suggests, you apply yourself.

A match is not proof of a live secret. Documentation, examples, placeholders and long-rotated
values all match the same patterns.

## If you find something live

Rotate the credential first. Then tell whoever handles security where you work. Then clean up
the history. In that order.

## Reducing what gets kept

These are documented settings, not tricks:

| What | How |
|---|---|
| Keep less history | `cleanupPeriodDays` in your settings file. The documented default is 30 days |
| Codex: prompt history | `[history]` in `config.toml` takes `persistence = "none"` and `max_bytes`. These govern `history.jsonl`, the record of prompts you typed, not the session transcripts under `~/.codex/sessions` |
| Codex: session transcripts | `codex exec --ephemeral` avoids writing rollout files for non-interactive runs. No documented equivalent for interactive sessions |
| Keep none at all | the `CLAUDE_CODE_SKIP_PROMPT_HISTORY` environment variable. You lose session resume |
| Clear one project | `claude project purge` |
| Stop secret files being read | `"permissions": { "deny": ["Read(./.env)", "Read(./.env.*)"] }`. Claude Code merges user, project, local and managed settings, so run `/status` for the loaded sources and `/permissions` for the resolved rules |

The deny rule covers the assistant's own file tools and the file commands it recognises in the
shell, such as `cat`, `head`, `tail` and `sed`, plus shell redirections. It does not cover a
script that opens the file itself. For enforcement at the operating system level, enable the
sandbox and set its filesystem boundary.

## Compatibility

**macOS only for now.** It branches on `uname` and has a GNU `stat` path for Linux, but that
path is untested, so treat Linux as unsupported until someone has run it there. Tools it
A tool with no transcript folder is reported as exactly that, a folder it could not find,
rather than as an absent installation: the tool may be installed but new, configured not to
persist sessions, or simply unused in that account.

## Licence

MIT. See [LICENSE](LICENSE).
