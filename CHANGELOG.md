# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Minor

- Report resources that receive no APRL verdict: `Start-WARACollector` adds a
  top-level `skippedResources` array to its output and writes one warning per run, in
  place of an error raised inside a class method. Because no error is raised,
  `-ErrorAction Stop` and a global `Stop` preference no longer end the run at the first
  such resource; use `-WarningAction Stop` for fail-fast. (#3)

### Patch

- Port Copilot issue-lifecycle tooling from `sfmc-tubfactory`: prompt files, PowerShell
  tools, config, and lint/dependency infra for the `raise → investigate → plan →
  implement → release` workflow. No changes to any function exported by the WARA
  PowerShell module. (#1)
- Add a fast-track route to the issue lifecycle for low-risk `XS` papercuts: a shared
  criteria file, a scan in `investigate-issue` and a decision in `approve-ready-for-plan`
  that flag eligible issues, a compact plan in `plan-issue`, a guard and escape in
  `implement-issue`, and the `lifecycle:fast-track` labels. No changes to any function
  exported by the WARA PowerShell module. (#4)
