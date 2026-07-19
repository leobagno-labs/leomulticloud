# PM-001: .gitignore silently hid dissertation evidence for 3 months

**Date:** 2026-07-19 (detection); drift began ~2026-04-05
**Severity:** Medium (no data lost, but single point of failure existed)
**Status:** Resolved

## Summary
All 18 RTO measurement CSVs from the dissertation experiments (April 2026)
existed only on the development laptop. A `tests/results/` rule in
.gitignore, added early in the project to exclude generated data,
silently prevented the primary research evidence from ever reaching
GitHub. Detected by accident on 2026-07-19 when committing the first
Phase 1 RPO measurement failed.

## Impact
- Published research (DOI 10.5281/zenodo.20189820) had its raw evidence
  files unprotected against laptop loss for ~3 months.
- Not affected: the dissertation itself, analysis documents, and summary
  tables were versioned and released (v4.0, Zenodo). The numbers were
  safe; the raw CSVs behind them were not.

## Timeline (UTC)
- 2026-02/03 - `tests/results/` added to .gitignore (intent: do not
  version generated test data)
- 2026-04-05 to 04-30 - dissertation RTO experiments write 18 CSVs into
  the ignored folder; git silently excludes them from every commit
- 2026-05 - v4.0 released, Zenodo DOI registered; raw CSVs remain
  local-only, unnoticed
- 2026-07-19 - `git add tests/results/*.csv` for the new RPO experiment
  is refused ("paths ignored by .gitignore"); investigation reveals the
  dissertation CSVs were never versioned
- 2026-07-19 - .gitignore fixed, all 19 CSVs (18 RTO + 1 RPO) committed
  and pushed (60f5fe5)

## Root Cause
A directory-level ignore rule (`tests/results/`) created for one purpose
(exclude test junk) collided months later with a new purpose (version
research evidence). The collision was invisible because ignoring is
silent by design: `git status` does not show ignored files, and no
verification step compared local evidence against the remote.
Contributing factor: a directory-level ignore cannot be overridden by
negation patterns (`!*.csv`), which also blocked the first fix attempt.

## Resolution
Replaced `tests/results/` with content-level rules:

    tests/results/*
    !tests/results/*.csv

This ignores junk inside the folder while versioning CSV evidence.
All dissertation and Phase 1 CSVs committed and pushed.

## Lessons Learned
1. Ignoring is silent; periodically audit with `git status --ignored`.
2. "It is committed" requires verification on the remote (browse
   GitHub), not just a successful local push.
3. Primary research data deserves its own backup checklist, independent
   of the code workflow.
4. Directory-level ignores (`dir/`) block negation exceptions; use
   `dir/*` + `!pattern` when exceptions are needed.

## Action Items
- [x] Fix .gitignore and push all evidence CSVs (done, 60f5fe5)
- [ ] Audit repo with `git status --ignored` for other hidden files
- [ ] Compress and back up `logs/` outside the laptop (Drive/Zenodo)
