# Release Process

This document describes how to create releases for this Terraform module.

## Overview

Releases are **fully automated** when you push a semantic version tag. The CI/CD pipeline will:

1. ✅ Validate the Terraform code
2. ✅ Run TFLint checks
3. ✅ Extract changelog notes
4. ✅ Create a GitLab/GitHub release
5. ✅ Generate downloadable source archives
6. ✅ (Optional) Notify Terraform Registry

## Quick Start

### Creating a Release

```bash
# 1. Ensure all changes are committed and pushed
git status

# 2. Update CHANGELOG.md with new version
# Add a new section at the top:
## [X.Y.Z] - YYYY-MM-DD

### Added
- New feature descriptions

### Changed
- Changed functionality

### Fixed
- Bug fixes

# 3. Commit the changelog
git add CHANGELOG.md
git commit -m "docs: prepare release vX.Y.Z"
git push

# 4. Create and push the tag
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z

# The CI/CD pipeline will automatically create the release!
```

### Using the Makefile (Alternative)

```bash
# Generate changelog and create tag
make changelog  # Generates CHANGELOG.md
make release    # Creates semantic version tag

# Push the tag to trigger release
git push --follow-tags
```

## Semantic Versioning

We follow [Semantic Versioning 2.0.0](https://semver.org/):

- **MAJOR** version (v2.0.0): Incompatible API changes
- **MINOR** version (v1.1.0): Backwards-compatible functionality
- **PATCH** version (v1.0.1): Backwards-compatible bug fixes

### Version Format

```
vMAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]

Examples:
  v1.0.0          # Stable release
  v1.2.3          # Stable release
  v2.0.0-beta.1   # Pre-release
  v1.0.0-rc.2     # Release candidate
  v1.0.0+20240115 # With build metadata
```

### Pre-release Versions

Pre-release versions are marked as "Pre-release" in GitHub/GitLab:

```bash
# Beta release
git tag -a v2.0.0-beta.1 -m "Beta release"

# Release candidate
git tag -a v2.0.0-rc.1 -m "Release candidate"

# Alpha release
git tag -a v2.0.0-alpha.1 -m "Alpha release"
```

## Release Checklist

Before creating a release:

- [ ] All CI/CD checks pass
- [ ] CHANGELOG.md updated with version notes
- [ ] Documentation updated (README.md, examples)
- [ ] Version follows semantic versioning rules
- [ ] All MRs/PRs for this release are merged
- [ ] Local testing completed
- [ ] Breaking changes documented (if MAJOR version)

## Automated Release Process

### GitLab (Primary)

Located in `.gitlab/release.yml`, triggered on tag push:

1. **Validation Stage**
   - Runs `terraform validate`
   - Runs `terraform fmt -check`
   - Runs `tflint` checks

2. **Release Stage**
   - Extracts version from tag (e.g., `v1.2.3` → `1.2.3`)
   - Extracts changelog section for this version
   - Creates GitLab Release with:
     - Release title
     - Changelog notes
     - Source archives (tar.gz, zip)
     - Link to CHANGELOG.md

3. **Optional Stages** (Manual Trigger)
   - Publish to Terraform Registry
   - Mirror release to GitHub

### GitHub (Mirror/Alternative)

Located in `.github/workflows/release.yml`:

Similar process but uses GitHub Actions instead of GitLab CI/CD.

## Terraform Registry Integration

### Prerequisites

For automatic Terraform Registry publishing:

1. **Configure Registry Webhook** (in CI/CD variables):
   ```
   TF_REGISTRY_WEBHOOK_URL = https://registry.terraform.io/webhooks/...
   ```

2. **Tag Format**: Must be `vX.Y.Z` (no pre-release identifiers)

3. **Repository Setup**: Module must be public and follow [Terraform Module structure](https://www.terraform.io/docs/language/modules/develop/structure.html)

### Manual Registry Publish

If automatic publishing fails:

1. Go to [Terraform Registry](https://registry.terraform.io/)
2. Sign in with your account
3. Navigate to your module
4. Click "Publish New Version"
5. Select the tag from the dropdown
6. Confirm publication

## Rollback Process

If a release has issues:

### Delete Tag and Release

```bash
# Delete local tag
git tag -d vX.Y.Z

# Delete remote tag
git push --delete origin vX.Y.Z

# Manually delete the release in GitLab/GitHub UI
```

### Create Patch Release

```bash
# Fix the issue
git commit -m "fix: critical bug in vX.Y.Z"

# Create new patch version
git tag -a vX.Y.Z+1 -m "Release vX.Y.Z+1 - fixes issue in vX.Y.Z"
git push origin vX.Y.Z+1
```

## Changelog Management

### Using git-chglog (Automated)

The `make changelog` command uses [git-chglog](https://github.com/git-chglog/git-chglog):

```bash
# Generate full changelog
make changelog

# Preview next version changelog
git-chglog --next-tag v1.2.3 v1.2.3
```

### Manual Changelog

If editing CHANGELOG.md manually, follow [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Vulnerability fixes
```

## Troubleshooting

### Release Pipeline Fails

**Problem**: Pipeline fails on tag push

**Solutions**:
1. Check CI/CD pipeline logs in GitLab/GitHub
2. Ensure terraform validation passes: `terraform validate`
3. Ensure formatting is correct: `terraform fmt -check -recursive`
4. Verify CHANGELOG.md has section for this version

### Tag Already Exists

**Problem**: Tag already exists locally or remotely

**Solution**:
```bash
# Delete local tag
git tag -d vX.Y.Z

# Delete remote tag (if already pushed)
git push --delete origin vX.Y.Z

# Recreate tag
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

### Release Not Appearing in Registry

**Problem**: Release created but not in Terraform Registry

**Solutions**:
1. Ensure module is public (not private)
2. Verify repository follows Terraform module structure
3. Check webhook configuration (if using webhooks)
4. Manually trigger registry refresh
5. Wait up to 30 minutes for registry sync

### Changelog Not Extracted

**Problem**: Release notes show "See CHANGELOG.md" instead of actual notes

**Solutions**:
1. Ensure CHANGELOG.md exists
2. Verify version format matches: `## [X.Y.Z]`
3. Check that version section exists in CHANGELOG.md
4. Ensure proper markdown formatting (no extra spaces)

## Best Practices

### Release Frequency

- **Patch releases** (bug fixes): As needed, quickly
- **Minor releases** (features): Every 2-4 weeks
- **Major releases** (breaking changes): Every 6-12 months

### Version Numbering

- Start at `v1.0.0` for first production release
- Use `v0.x.x` for initial development (breaking changes allowed)
- Increment MAJOR for breaking changes (even if small)
- Document breaking changes clearly in CHANGELOG

### Release Notes Quality

- ✅ **DO**: Write clear, user-focused descriptions
- ✅ **DO**: Link to relevant issues/MRs
- ✅ **DO**: Highlight breaking changes prominently
- ❌ **DON'T**: Use internal jargon or ticket numbers without context
- ❌ **DON'T**: Copy commit messages directly

### Example Quality Release Notes

```markdown
## [2.0.0] - 2024-01-15

### Breaking Changes ⚠️

- **Variable Renamed**: `tokens_variables` → `deploy_tokens`
  - Update your configurations: `terraform state mv ...`
  - Migration guide: [docs/migration-v2.md](docs/migration-v2.md)

### Added

- Support for multiple groups in deploy tokens (#123)
- New output variables for enhanced debugging (#145)
- Comprehensive validation rules (#156)

### Changed

- Output variable names now use underscores instead of hyphens (#134)
- Improved error messages for invalid configurations (#142)

### Fixed

- Resolved perpetual diff issue with `expiring_soon_tokens` output (#167)
- Corrected attribute references in outputs to match provider schema (#168)

### Documentation

- Added CONTRIBUTING.md with development workflow (#150)
- Enhanced examples with real-world use cases (#153)
```

## GitHub vs GitLab Releases

### Use GitLab When:
- Primary repository is on GitLab
- Using GitLab CI/CD exclusively
- Target audience uses GitLab

### Use GitHub When:
- Repository is mirrored to GitHub
- Want broader discoverability
- Terraform Registry requires GitHub

### Use Both When:
- Maximum visibility desired
- Mirror repository between platforms
- Different audiences on each platform

**Note**: Both workflows can run simultaneously without conflict.

## Support

For questions about the release process:
- Open an issue with label `question` or `release`
- Check [CONTRIBUTING.md](CONTRIBUTING.md) for development workflow
- Contact maintainers (see [CODEOWNERS](CODEOWNERS))
