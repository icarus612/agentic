
# code-review

## Round 1 — 10-16-26

```
verdict: tentative
next: proceed
blocking: 0
non-blocking: 2
```

### Findings

- [non-blocking] agent-agnostic/hooks/smart-test.sh:293-296 - EXIT/TERM/INT/HUP traps are installed at script top level for the whole hook. Verified safe: `kill_contained_group` is a no-op while `RUN_CONTAINED_PID` is empty, the group is the job's own pgid (`set -m`), the variable is cleared after each run so a stale pid is never signalled, and if job control were unavailable `kill -- -pid` hits ESRCH and is swallowed. It can never signal the hook's parent or an unrelated group. Only TERM is sent (no KILL escalation), which matches DP-3 (no internal timeout); a runner that ignores TERM would survive. Consistent with assumption A1; 3.3's measurement is the check.
- [non-blocking] agent-agnostic/hooks/smart-test.sh:735-770 - when `find_js_package_dir` finds no package (none with a non-orchestrator `scripts.test`), the hook no longer runs anything from `$PWD`; it falls to the existing "No test runner configured and no tests found" error (exit 2) only when `require_tests` is true and no sibling test file exists, else tests_run=0 and it passes silently. Sane and matches plan 2.5, but note it is a behavior change: a repo whose only test script is a root orchestrator (`turbo test`) now gets no source-edit test run. Intended per the plan.

### Open questions

None blocking. A1 (harness sends catchable SIGTERM on hook termination) remains unverifiable here; 3.3 is the check.

### Verified

- Re-ran suites: smart-test-process-cleanup 6/0, smart-test-role-scope 7/0, lane-artifact-shell-guard 94/0, verify-run-scope-docs-symlink 9/0, push-pr-gate-refusal 18/0, build-dispatch-verify-scope 6/0. `bash -n` on smart-test.sh ok. Independent guard replay: `cd .../contracts && { cat >> l8.md; }` denied, exit 2, stderr names the resolved path.
- Plan coverage: 1.1-1.5 and 2.1-2.5 all shipped; no unplanned scope. The only remaining ready-only string in agent-agnostic/ and docs/ is the intended "ready/proceed or tentative/proceed" refusal sentence (push-pr/SKILL.md:63). `dae/build.md:27` correctly left unedited.
- Guard (2.3): vcwd seeded from payload cwd, cd/pushd/popd tracked, subshell stack via ( ), raw-token check retained, fail-open preserved. No new dedupe issue.
- verify-run-scope (2.4): `-L` plus `realpath -m`, component-safe prefix `case`, same GNU realpath assumption as seven sibling hooks. Header updated.
- No attribution trailers in the diff or commit messages (scanned).
- Process notes: l2 builder writing tests and fix itself bypassed the blind contract-tester/coder separation. Deviation from the skill mapping, but the 1.3 cases are the plan's table verbatim and were red-first per its exit report, so not blocking; flagging for the record. l1/l4 each used one coder rework round, within norms.
- Not re-verified by me: treehouse-side checks (finalize predicate vs real tentative pr-review, 572/572 scope) and 3.2/3.3, which are Record/post-install stages.
