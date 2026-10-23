# tgstation-slop

AI-made reproductions and **candidate fixes** for open [/tg/station](https://github.com/tgstation/tgstation)
issues. **Nobody has reviewed these.** Treat every verdict and every fix as a lead, not as a fact.

On 2026-10-23, AI agents took the open issues one work unit at a time (a unit is one issue,
or a group of duplicates and related issues). Each ran a private tgstation server with admin
tools, tried to reproduce the bug in game, read the code for the cause, committed a fix where
there was one, and checked the fix in game where it could.

## Where things are

| | |
|---|---|
| [reports/](reports) | one write-up per unit: what the bug is, how it was reproduced (or why it wasn't), the cause in the code, the fix, how it was checked, and what wasn't. Units without a fix have one too |
| [INDEX.md](INDEX.md) | every issue investigated so far, with its status, a one-line result, its write-up and its fix branch |
| `fix/N` branches | one per unit with a fix, based on tgstation master `87b93338`, one commit per issue (`Fix issue N: ...`). Each commit ends with a `Report:` trailer linking its write-up here |

## Statuses

- **verified**: reproduced, fixed, and the fix checked in game.
- **fixed**: fix committed but only partly checked, or checked by calling the code directly instead
  of the exact player action. The write-up says which.
- **not-reproduced**: the bug didn't happen on master `87b93338`, often because it was already fixed
  upstream or the code has changed since. Some of these issues can probably be closed.
- **reproduced**: seen, but no fix yet.
- **blocked**: needs something the setup couldn't provide, such as a real Dream Seeker client.

## Caveats

- The fixes are unreviewed. Some write-ups mark a design choice or a behaviour change for a
  maintainer to decide.
- The test client didn't render pixels, so visual fixes were checked by state, not by eye.
  The write-ups say so where it matters.
- Each branch is based on a fixed master from 2026-10-23 and isn't kept up to date.
