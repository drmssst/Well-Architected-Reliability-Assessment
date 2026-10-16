# Fork notes

This is a fork of [Azure/Well-Architected-Reliability-Assessment](https://github.com/Azure/Well-Architected-Reliability-Assessment). Upstream has been inactive since June 2025, so this fork is maintained independently and versioned on its own.

## Version identity

Fork versions are `<upstream version>-eoa.<N>`, for example `1.0.6-eoa.1`.

- `ModuleVersion` in `src/modules/wara/wara.psd1` stays numeric and is not changed by the fork (1.0.6; analyzer 2.2.0). The fork version lives in git tags and in this file.
- `N` is `0` for a baseline identical to upstream and increases by one for each fork release.
- When the fork is rebased onto a new upstream release, the version becomes `<new upstream version>-eoa.1`.
- Each release is a tag named `v<version>`. Consumers vendor from a tag, never from a branch.

| Tag | Commit | Meaning |
| --- | --- | --- |
| `v1.0.6-eoa.0` | `8683227` | Baseline. Identical to upstream `main` at that commit, which is the `v1.0.6` tag plus 8 upstream commits (formatting, exception handling, Office process handling and a `New-PPTFile` parameter fix in the analyzer and reports generator). |
| `v1.0.6-eoa.1` | `acc78b5` | First fork release. Adds `skippedResources` (below). |

## Fork-only changes to the module

### v1.0.6-eoa.1

- `Start-WARACollector` output gains a `skippedResources` array. A resource is listed when `WARAinScopeResTypes.csv` flags its type as covered but `recommendations.json` has no recommendation for the type, automated or manual. Such a resource gets no APRL verdict and has no row in `impactedResources`.
- Each entry has `id`, `name`, `type`, `location`, `subscriptionId`, `resourceGroup` and `reason`. The only reason code so far is `NoMatchingRecommendation`.
- One warning is written per run with the resource and type counts. No error is raised.
- Source: `src/modules/wara/wara.psm1` (fork PR #22).

## Other content in this fork

The `.github`, `tools`, `config` and `docs` folders, the markdownlint settings, `package.json`, `README.md` and `CHANGELOG.md` are this fork's own issue-lifecycle tooling. They are not part of the module. Consumers who vendor the module take `src/modules/wara` and the `LICENSE` only.