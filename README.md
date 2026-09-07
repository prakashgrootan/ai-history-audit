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
curl -fsSLo check-my-ai-history.sh https://raw.githubusercontent.com/prakashgrootan/ai-history-audit/v1.0.0/check-my-ai-history.sh
cat check-my-ai-history.sh          # or: open -e check-my-ai-history.sh
bash check-my-ai-history.sh
rm check-my-ai-history.sh
```

The URL names the `v1.0.0` tag rather than `main`, so the file cannot change under you between
reading it here and running it. `cat` prints and returns; use `less` if you prefer a pager,
and press `q` to leave it.

Do not pipe this, or any script, from the internet straight into your shell.

It reports, for Claude Code and Codex:

- how many transcript files exist, split into sessions you had and transcripts written by
  helper agents on your behalf
- how far back they go, and how much disk they use
- whether another account on the machine looks able to reach them. This is a mode-bit
  heuristic: it reads POSIX permissions on the folders in the path and on a sample of up to 50
  transcripts. It does not read ACLs, does not look below the transcript root, and cannot tell
  whether a particular account belongs to the group owning each folder. A positive means worth
  checking; a negative means nothing was found by mode bits alone
- how many files contain credential-shaped text
- which of the recommended settings you have not applied

## What it deliberately does not do

- **It never prints the contents of a transcript.** Only counts, dates and sizes.
- **It never prints a matched secret.** For credential-shaped text it reports how many files
  matched, never what matched or where.
- **It sends nothing anywhere.** No network calls at all.
- **It writes nothing and changes no settings.** Read-only. Any fix it suggests, you apply
  yourself.

A match is not proof of a live secret. Documentation, examples, placeholders and long-rotated
values all match the same patterns.

## If you find something live

Rotate the credential first. Then tell whoever handles security where you work. Then clean up
the history. In that order.

## Reducing what gets kept

All four of these are documented settings, not tricks:

| What | How |
|---|---|
| Keep less history | `cleanupPeriodDays` in your settings file. The documented default is 30 days |
| Codex: keep no history | `[history]` with `persistence = "none"` in `config.toml` |
| Codex: cap the history file | `[history]` with `max_bytes`, which drops the oldest entries past the cap |
| Keep none at all | the `CLAUDE_CODE_SKIP_PROMPT_HISTORY` environment variable. You lose session resume |
| Clear one project | `claude project purge` |
| Stop secret files being read | `"permissions": { "deny": ["Read(./.env)", "Read(./.env.*)"] }` |

The deny rule covers the assistant's own file tools and the file commands it recognises in the
shell, such as `cat`, `head`, `tail` and `sed`, plus shell redirections. It does not cover a
script that opens the file itself. For enforcement at the operating system level, enable the
sandbox and set its filesystem boundary.

## Compatibility

**macOS only for now.** It branches on `uname` and has a GNU `stat` path for Linux, but that
path is untested, so treat Linux as unsupported until someone has run it there. Tools it
cannot find are reported as "not installed" rather than failing.

## Licence

MIT. See [LICENSE](LICENSE).
