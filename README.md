# ai-history-audit

Your AI coding assistant keeps a plain-text record of your work with it: the files it opened,
the commands it ran, and what those printed. Claude Code's own documentation says so, and adds
that these files are not encrypted and that operating system file permissions are the only
thing protecting them.

This script tells you what is on your own machine.

## What it does

```bash
curl -fsSLo check-my-ai-history.sh https://raw.githubusercontent.com/prakashgrootan/ai-history-audit/main/check-my-ai-history.sh
less check-my-ai-history.sh
bash check-my-ai-history.sh
```

Read it before you run it. Do not pipe scripts from the internet into your shell.

It reports, for Claude Code and Codex:

- how many transcript files exist, split into sessions you had and transcripts written by
  helper agents on your behalf
- how far back they go, and how much disk they use
- whether another account on the machine can actually reach them, checking every folder in the
  path rather than just the last one
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
| Keep none at all | the `CLAUDE_CODE_SKIP_PROMPT_HISTORY` environment variable. You lose session resume |
| Clear one project | `claude project purge` |
| Stop secret files being read | `"permissions": { "deny": ["Read(./.env)", "Read(./.env.*)"] }` |

The deny rule covers the assistant's own file tools and the file commands it recognises in the
shell, such as `cat`, `head`, `tail` and `sed`, plus shell redirections. It does not cover a
script that opens the file itself. For enforcement at the operating system level, enable the
sandbox and set its filesystem boundary.

## Compatibility

Written for macOS, where it is tested. It uses BSD `stat` with a GNU `stat` fallback, so it
should work on Linux, but that path is untested. Reports on tools it cannot find as "not
installed" rather than failing.

## Licence

MIT. See [LICENSE](LICENSE).
