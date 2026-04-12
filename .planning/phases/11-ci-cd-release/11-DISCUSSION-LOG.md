# Phase 11: CI/CD & Release - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-03
**Phase:** 11-ci-cd-release
**Areas discussed:** CI workflow structure, Release & versioning flow, Dependency management, Repo & branch policy

---

## CI Workflow Structure

### Workflow Organization
| Option | Description | Selected |
|--------|-------------|----------|
| Single workflow | One ci.yml with jobs: lint, test matrix, integration-test | ✓ |
| Split workflows | Separate ci.yml and release.yml | |
| Three workflows | ci.yml, integration.yml, release.yml | |

**User's choice:** Single workflow
**Notes:** Release was later separated into its own release.yml (different triggers)

### Integration Test Timing
| Option | Description | Selected |
|--------|-------------|----------|
| Every PR and main | Always run stripe-mock integration tests | ✓ |
| Only on main branch | PRs run unit tests only | |
| PR + main, optional on PR | Integration runs but not required | |

**User's choice:** Every PR and main

### Matrix Failure Strategy
| Option | Description | Selected |
|--------|-------------|----------|
| Fail-fast | Cancel remaining on first failure | ✓ |
| Run all combos | Complete all entries even on failure | |

**User's choice:** Fail-fast

### Caching Strategy
| Option | Description | Selected |
|--------|-------------|----------|
| Cache deps + build | Cache _build/ and deps/ on mix.lock hash | ✓ |
| Cache deps only | Rebuild every time | |
| No caching | Clean build every time | |

**User's choice:** Cache deps + build

### Matrix Combos
| Option | Description | Selected |
|--------|-------------|----------|
| 3 combos | 1.15/OTP26, 1.17/OTP27, 1.19/OTP28 | ✓ |
| Full cross-product | 9 jobs | |
| 2 combos (minimal) | Floor + latest only | |

**User's choice:** 3 combos

### Lint Job Placement
| Option | Description | Selected |
|--------|-------------|----------|
| Separate lint job | Dedicated job on latest Elixir/OTP | ✓ |
| Lint on latest matrix entry | Add lint steps to 1.19/OTP28 entry | |

**User's choice:** Separate lint job

### stripe-mock Setup
| Option | Description | Selected |
|--------|-------------|----------|
| Service container | GitHub Actions services block | ✓ |
| Docker run in step | Explicit docker run -d | |
| You decide | Claude picks | |

**User's choice:** Service container

### Integration Test CI Job
| Option | Description | Selected |
|--------|-------------|----------|
| Separate integration job | Dedicated job with stripe-mock | ✓ |
| Integration in every matrix entry | 3x Docker overhead | |
| Integration on latest only | Muddies matrix purpose | |

**User's choice:** Separate integration job

### Setup Action
| Option | Description | Selected |
|--------|-------------|----------|
| erlef/setup-beam | Official BEAM ecosystem action | ✓ |
| You decide | Claude picks | |

**User's choice:** erlef/setup-beam

### CI Triggers
| Option | Description | Selected |
|--------|-------------|----------|
| PR + push to main | Standard for OSS | ✓ |
| PR only | Relies on branch protection | |
| Push only | No pre-merge checks on forks | |

**User's choice:** PR + push to main

### Hex Build Smoke Test
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, smoke test hex.build | Catch packaging issues early | ✓ |
| No, skip hex.build in CI | Only at release time | |

**User's choice:** Yes

### MixAudit
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, include MixAudit | Run mix deps.audit in lint job | ✓ |
| No, skip MixAudit | Rely on Dependabot | |

**User's choice:** Yes

### Concurrency
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, cancel in-progress | Concurrency groups | ✓ |
| No concurrency control | Let all runs complete | |

**User's choice:** Cancel in-progress

### Test Partitioning
| Option | Description | Selected |
|--------|-------------|----------|
| No partitions | Single ExUnit process | ✓ |
| Partition across 2 jobs | MIX_TEST_PARTITION | |

**User's choice:** No partitions

### Path Filtering
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, skip on docs-only | paths-ignore for .md, .planning/, guides/ | ✓ |
| No, always run CI | Run on every change | |
| Partial skip | Skip tests but run lint+docs | |

**User's choice:** Skip on docs-only

### Notifications
| Option | Description | Selected |
|--------|-------------|----------|
| GitHub defaults only | Built-in PR checks and email | ✓ |
| Add Slack notification | Post to Slack on failure | |
| You decide | Claude picks | |

**User's choice:** GitHub defaults only

### Permissions
| Option | Description | Selected |
|--------|-------------|----------|
| Minimal permissions | contents: read at workflow level | ✓ |
| Default permissions | GitHub's default token scope | |

**User's choice:** Minimal permissions

### Docker Layer Caching
| Option | Description | Selected |
|--------|-------------|----------|
| No caching | Pull fresh each run (~5s, 50MB) | ✓ |
| Cache with buildx | Cache Docker image layer | |

**User's choice:** No caching

### GitHub Actions Version Pinning
| Option | Description | Selected |
|--------|-------------|----------|
| Major tag | actions/checkout@v4 | ✓ |
| Full SHA pin | Maximum reproducibility | |
| Exact version tag | actions/checkout@v4.2.2 | |

**User's choice:** Major tag

### Runner
| Option | Description | Selected |
|--------|-------------|----------|
| ubuntu-latest | Standard free runner | ✓ |
| ubuntu-22.04 (pinned) | Specific version | |
| Multi-OS | Also test macOS | |

**User's choice:** ubuntu-latest

### Job Dependencies
| Option | Description | Selected |
|--------|-------------|----------|
| All jobs in parallel | Fastest total CI time | ✓ |
| Test needs lint | Serial dependency | |
| Integration needs test | Logical ordering | |

**User's choice:** All parallel

### Artifacts
| Option | Description | Selected |
|--------|-------------|----------|
| No artifacts | Docs/package published on release | ✓ |
| Upload docs artifact | Review docs on PRs | |
| Upload hex package | Inspect before publish | |

**User's choice:** No artifacts

### Coverage
| Option | Description | Selected |
|--------|-------------|----------|
| No coverage tracking | High-value specs over metrics | ✓ |
| Coveralls integration | External coverage tracking | |
| Local coverage only | mix test --cover | |

**User's choice:** No coverage tracking

### Timeouts
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, set timeouts | timeout-minutes: 15 | ✓ |
| No explicit timeouts | GitHub default 6-hour | |
| You decide | Claude picks values | |

**User's choice:** 15 minute timeouts

### Environment Variables
| Option | Description | Selected |
|--------|-------------|----------|
| Workflow-level env block | MIX_ENV=test at top | ✓ |
| Per-step env vars | Set on each step | |
| You decide | Claude picks | |

**User's choice:** Workflow-level

### Workflow File Naming
| Option | Description | Selected |
|--------|-------------|----------|
| ci.yml | Standard Elixir OSS convention | ✓ |
| test.yml | Emphasizes testing | |
| elixir.yml | Language-specific | |

**User's choice:** ci.yml

### Compile Flags
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, warnings-as-errors | mix compile --warnings-as-errors | ✓ |
| No, warnings are warnings | Only fail on errors | |
| Warnings-as-errors on main only | Lenient for PRs | |

**User's choice:** Warnings-as-errors

---

## Release & Versioning Flow

### Hex Publishing Automation
| Option | Description | Selected |
|--------|-------------|----------|
| Fully automatic | Auto-publish on Release Please merge | ✓ |
| Manual trigger after release | Separate manual workflow | |
| Semi-auto with environment approval | Pause for approval | |

**User's choice:** Fully automatic

### Pre-1.0 Versioning
| Option | Description | Selected |
|--------|-------------|----------|
| Start at 0.1.0, semver-ish | Breaking=minor, features=patch | ✓ |
| Jump to 1.0.0 | Ship as production immediately | |
| 0.x with explicit 1.0 milestone | Iterate before committing | |

**User's choice:** Start at 0.1.0

### Release Please Configuration
| Option | Description | Selected |
|--------|-------------|----------|
| release-please-config.json (manifest) | Modern, flexible approach | ✓ |
| Workflow-level config | All config in YAML | |
| You decide | Claude picks | |

**User's choice:** Manifest-based config

### Version Bump in mix.exs
| Option | Description | Selected |
|--------|-------------|----------|
| Auto-update mix.exs | Release Please updates @version | ✓ |
| Manual version bump | Update manually before merge | |

**User's choice:** Auto-update

### HexDocs Publishing
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, auto-publish docs | Part of mix hex.publish | ✓ |
| Separate docs publish step | Independent docs updates | |
| You decide | Claude handles | |

**User's choice:** Auto-publish (default hex.publish behavior)

### Pre-Publish CI Re-run
| Option | Description | Selected |
|--------|-------------|----------|
| Rely on branch protection | No re-run before publish | ✓ |
| Re-run checks before publish | Belt-and-suspenders | |

**User's choice:** Rely on branch protection

### Changelog Format
| Option | Description | Selected |
|--------|-------------|----------|
| Release Please default | Auto from Conventional Commits | ✓ |
| Keep a Changelog format | keepachangelog.com structure | |
| You decide | Claude picks | |

**User's choice:** Release Please default

### Git Tag Format
| Option | Description | Selected |
|--------|-------------|----------|
| v-prefixed: v0.1.0 | Standard Elixir convention | ✓ |
| No prefix: 0.1.0 | Plain version numbers | |
| You decide | Claude picks | |

**User's choice:** v-prefixed

### Release Notes Content
| Option | Description | Selected |
|--------|-------------|----------|
| Auto-generated only | From Conventional Commits | ✓ |
| Auto-generated + upgrade guide | Plus manual migration section | |
| You decide | Claude determines | |

**User's choice:** Auto-generated only

### Release Workflow Trigger
| Option | Description | Selected |
|--------|-------------|----------|
| Every push to main | Standard approach | ✓ |
| Manual/workflow_dispatch only | More control | |
| Scheduled (weekly) | Batch releases | |

**User's choice:** Every push to main

### Hex Package Metadata
| Option | Description | Selected |
|--------|-------------|----------|
| Standard metadata | name, description, licenses, links, files | ✓ |
| Minimal metadata | Just basics | |
| You decide | Claude includes standard | |

**User's choice:** Standard metadata

### Release Please Type
| Option | Description | Selected |
|--------|-------------|----------|
| elixir | Built-in Elixir support | ✓ |
| simple | Generic type | |
| You decide | Claude picks | |

**User's choice:** elixir

### Separate Release Workflow
| Option | Description | Selected |
|--------|-------------|----------|
| Separate release.yml | Different triggers from CI | ✓ |
| All in ci.yml | Single file | |
| You decide | Claude organizes | |

**User's choice:** Separate release.yml

---

## Dependency Management

### Update Frequency
| Option | Description | Selected |
|--------|-------------|----------|
| Weekly | Check every Monday | ✓ |
| Monthly | Once a month | |
| Daily | Every day | |

**User's choice:** Weekly

### GitHub Actions Updates
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, both mix + actions | Two ecosystem entries | ✓ |
| Mix deps only | Manually update actions | |

**User's choice:** Both ecosystems

### Dependency Grouping
| Option | Description | Selected |
|--------|-------------|----------|
| Group by type | Dev deps grouped, prod individual | ✓ |
| Individual PRs | One per dependency | |
| Group all | Single PR for all | |

**User's choice:** Group by type

### Auto-merge
| Option | Description | Selected |
|--------|-------------|----------|
| No auto-merge | Manual review for all | |
| Auto-merge patches only | Patch versions if CI passes | ✓ |
| Auto-merge patches + minor | Only major needs review | |

**User's choice:** Auto-merge patches only

### Open PR Limit
| Option | Description | Selected |
|--------|-------------|----------|
| 5 (default) | Standard limit | ✓ |
| 10 | Higher limit | |
| 3 | Conservative | |

**User's choice:** 5

### Commit Message Style
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, Conventional Commits | prefix: "chore" | ✓ |
| Default Dependabot format | Standard messages | |
| You decide | Claude picks | |

**User's choice:** Conventional Commits

### Ignore Rules
| Option | Description | Selected |
|--------|-------------|----------|
| No ignores | Monitor all deps | ✓ |
| Ignore dev-only major bumps | Less noise | |
| You decide | Claude sets up | |

**User's choice:** No ignores

### Labels
| Option | Description | Selected |
|--------|-------------|----------|
| Add 'dependencies' label | Easy to filter | ✓ |
| No labels | Keep clean | |
| Labels + assignee | More metadata | |

**User's choice:** Dependencies label

### Security Updates
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, enable security updates | Default, critical for payments | ✓ |
| Rely on MixAudit only | CI-only detection | |

**User's choice:** Enable security updates

### Reviewers
| Option | Description | Selected |
|--------|-------------|----------|
| No reviewers | Solo maintainer | ✓ |
| Assign repo owner | Explicit assignment | |

**User's choice:** No reviewers

### Target Branch
| Option | Description | Selected |
|--------|-------------|----------|
| main | Standard | ✓ |
| Dedicated deps branch | Batch updates | |

**User's choice:** main

### Rebase Strategy
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, auto-rebase | Default behavior | ✓ |
| No auto-rebase | Manual rebase | |

**User's choice:** Auto-rebase

### Milestones
| Option | Description | Selected |
|--------|-------------|----------|
| No milestones | Deps are ongoing maintenance | ✓ |
| Assign to current milestone | Track all work | |

**User's choice:** No milestones

### Update Scope
| Option | Description | Selected |
|--------|-------------|----------|
| All updates | Patch, minor, and major | ✓ |
| Patch + minor only | Skip major | |
| Security only | Minimal | |

**User's choice:** All updates

### Vendoring
| Option | Description | Selected |
|--------|-------------|----------|
| No vendoring | Fetch from hex.pm | ✓ |
| Vendor deps | Commit deps/ to repo | |

**User's choice:** No vendoring

### Schedule Day
| Option | Description | Selected |
|--------|-------------|----------|
| Monday | Default | ✓ |
| Wednesday | Mid-week | |
| You decide | Claude picks | |

**User's choice:** Monday

### Hex Organization
| Option | Description | Selected |
|--------|-------------|----------|
| Public package | lattice_stripe on hex.pm | ✓ |
| Under Hex org | Requires membership | |

**User's choice:** Public package

### Hex Retire Strategy
| Option | Description | Selected |
|--------|-------------|----------|
| Manual retire when needed | mix hex.retire on demand | ✓ |
| Document a retire policy | Written guidelines | |
| You decide | Claude determines | |

**User's choice:** Manual

### Lock File
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, commit mix.lock | Reproducible builds | ✓ |
| No, gitignore it | Fresh resolution each time | |

**User's choice:** Commit mix.lock

### HEX_API_KEY Management
| Option | Description | Selected |
|--------|-------------|----------|
| Manual, rotate annually | Simple, sufficient for OSS | ✓ |
| Short-lived keys | 30-day expiry | |
| You decide | Claude picks | |

**User's choice:** Manual, rotate annually

### MixAudit Schedule
| Option | Description | Selected |
|--------|-------------|----------|
| CI only | Runs in lint job | ✓ |
| Daily cron + CI | Separate scheduled audit | |
| You decide | Claude determines | |

**User's choice:** CI only

---

## Repo & Branch Policy

### Merge Strategy
| Option | Description | Selected |
|--------|-------------|----------|
| Squash merge | One commit per PR on main | ✓ |
| Merge commit | Preserve PR commit history | |
| Rebase merge | Linear, individual commits | |

**User's choice:** Squash merge

### Branch Protection
| Option | Description | Selected |
|--------|-------------|----------|
| Require CI + no force push | Standard protection | ✓ |
| Strict protection | Plus reviews, up-to-date | |
| No protection | Full flexibility | |

**User's choice:** CI + no force push

### Required Checks
| Option | Description | Selected |
|--------|-------------|----------|
| All CI jobs | Lint, matrix, integration | ✓ |
| Lint + latest matrix only | Older versions informational | |
| You decide | Claude picks | |

**User's choice:** All CI jobs

### README Badges
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, key badges | CI, Hex, HexDocs, License | ✓ |
| Minimal badges | Hex + license only | |
| No badges | Clean README | |

**User's choice:** Key badges

### Auto-delete Branches
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, auto-delete | Clean branch list | ✓ |
| No auto-delete | Keep branches | |

**User's choice:** Auto-delete

### CONTRIBUTING.md
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, basic CONTRIBUTING.md | Dev setup, tests, commits, PR process | ✓ |
| Defer to later | Add when contributors arrive | |
| README section only | Lighter weight | |

**User's choice:** Basic CONTRIBUTING.md

### Issue/PR Templates
| Option | Description | Selected |
|--------|-------------|----------|
| Basic templates | Bug report, feature request, PR template | ✓ |
| Defer templates | Add later | |
| PR template only | Skip issue templates | |

**User's choice:** Basic templates

### LICENSE File
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, add MIT LICENSE | Required for Hex, currently missing | ✓ |
| Defer | Outside Phase 11 scope | |

**User's choice:** Add MIT LICENSE

### SECURITY.md
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, basic SECURITY.md | Vulnerability reporting process | ✓ |
| Defer to later | Add formal policy later | |
| GitHub security advisories only | Feature, not file | |

**User's choice:** Basic SECURITY.md

### Branch Naming Convention
| Option | Description | Selected |
|--------|-------------|----------|
| Conventional prefix | feat/, fix/, chore/, docs/ | ✓ |
| No convention | Any name goes | |
| You decide | Claude picks | |

**User's choice:** Conventional prefix

### Commit Signing
| Option | Description | Selected |
|--------|-------------|----------|
| No requirement | Squash merge signed by GitHub | ✓ |
| Require signed commits | GPG/SSH signatures | |

**User's choice:** No requirement

### Stale Bot
| Option | Description | Selected |
|--------|-------------|----------|
| No stale bot | Manual triage | ✓ |
| Add stale bot | Auto-close after 90 days | |

**User's choice:** No stale bot

### CODEOWNERS
| Option | Description | Selected |
|--------|-------------|----------|
| No CODEOWNERS | Solo maintainer, redundant | ✓ |
| Yes, add CODEOWNERS | Auto-assign reviewer | |

**User's choice:** No CODEOWNERS

### GitHub Repo Settings
| Option | Description | Selected |
|--------|-------------|----------|
| Standard OSS settings | Issues on, Wiki off, Discussions off, topics | ✓ |
| Enable Discussions | Community interaction | |
| You decide | Claude picks | |

**User's choice:** Standard OSS settings

### .gitignore
| Option | Description | Selected |
|--------|-------------|----------|
| Looks good as-is | All standard artifacts covered | ✓ |
| Add .env files | Prevent secret leakage | |
| You decide | Claude checks | |

**User's choice:** As-is

---

## Claude's Discretion

- Exact paths-ignore patterns for docs-only CI skip
- Issue template field structures
- CONTRIBUTING.md wording and dev setup instructions
- SECURITY.md wording and response commitments
- PR template checklist items
- Dependabot auto-merge implementation details

## Deferred Ideas

None — discussion stayed within phase scope
