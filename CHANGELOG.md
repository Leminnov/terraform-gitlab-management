# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive output variables for all resources
- Support for multiple groups/projects in group_access_tokens and project_access_tokens
- Support for multiple groups in deploy_tokens
- Apache 2.0 license
- TFLint configuration

### Changed
- Updated from CC BY-SA 4.0 to Apache License 2.0
- Renamed `tokens_variables` to `deploy_tokens`
- Output variable names now use underscores instead of hyphens
- Enhanced outputs with detailed metadata and helper outputs
- Removed `expiring_soon_tokens` output (caused perpetual diffs)

### Fixed
- Added missing `key` field to `deploy_tokens` transformation
- Corrected output attributes to match actual GitLab provider resource schema
- Fixed typos in example file

## [1.0.0] - Initial Release

### Added
- Initial module implementation
- Support for GitLab group variables
- Support for GitLab project variables
- Support for GitLab deploy tokens
- Support for GitLab pipeline schedules
- Support for GitLab runners
- Support for GitLab group access tokens
- Support for GitLab project access tokens
