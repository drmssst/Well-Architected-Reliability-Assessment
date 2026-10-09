# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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
