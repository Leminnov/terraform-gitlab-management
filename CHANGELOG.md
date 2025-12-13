# Changelog

All notable changes to this project will be documented in this file.

## [11.0.0] - 2025-12-13
- Adds explicit key assignment to variables

Ensures that the 'key' attribute is explicitly assigned within the example variable definitions, improving clarity and consistency.

Removes redundant key assignment within local variables as it is implicitly defined.
## [10.0.0] - 2025-12-13
- Migrates CI/CD pipeline to GitLab

Migrates the CI/CD pipeline from GitHub Actions to GitLab CI, enabling release process handling via GitLab features.

Removes the previous GitHub Actions workflow and introduces corresponding GitLab CI configuration files.

Ensures .gitlab/global.yml ends with a newline.
- Migrates CI/CD pipeline to GitLab

Migrates the CI/CD pipeline from GitHub Actions to GitLab CI, enabling release process handling via GitLab features.

Removes the previous GitHub Actions workflow and introduces corresponding GitLab CI configuration files.
- fix(gitlab): Ensure .gitlab/global.yml ends with a newline
- Migrates CI/CD pipeline to GitLab

This commit migrates the CI/CD pipeline from GitHub Actions to GitLab CI.
The release process is now handled by GitLab CI, leveraging its features
for validation, release creation, and registry notification.

The previous GitHub Actions workflow is removed, and corresponding GitLab
CI configuration files are added to define the pipeline stages and jobs.
- Auto stash before rebase of "develop"
- ci: Optimize pre-commit job script by removing redundant commands
- ci: Update pre-commit job image to Ubuntu 24.04 LTS
- Update README to match CI terraform-docs output

The README provider version now reflects the version constraint from
versions.tf (~> 18.6) instead of the locked version (18.6.1).

This resolves the CI pre-commit failure where terraform-docs was
modifying the README during the pipeline run.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
- Relax gitlab provider version constraint

Updates the gitlab provider version constraint to allow for more flexibility in minor version upgrades.

This change removes the specific patch version, allowing updates within the 18.6.x range without requiring immediate code modifications.
- Enables pre-commit and simplifies tflint

Adds pre-commit installation to the CI pipeline to ensure consistent code formatting and quality.

Simplifies tflint execution by removing the redundant --chdir parameter.
- Updates terraform-docs version

Specifies the full version string for terraform-docs in mise.toml.

This ensures that the correct and intended version of
terraform-docs is used, avoiding potential compatibility
issues or unexpected behavior that might arise from
implicit version resolution.
- Updates pre-commit image version

Updates the pre-commit job image to a newer Ubuntu version.

This ensures the pre-commit hooks run in an environment with the latest tooling and security updates, potentially resolving compatibility issues and improving reliability.
- Updates dependencies

Updates the version of terraform-docs and removes the tilde from the gitlab provider version constraint.
- Updates gitlab provider version constraint.

Updates the gitlab provider version constraint in the README to allow for more flexible versioning.
This ensures compatibility with a wider range of minor and patch versions, while still maintaining a degree of control over the provider version used.
- Adds terraform-docs version check

Adds a check for the terraform-docs version during the pre-commit stage to ensure the tool is available and properly configured.
- Improves pre-commit job output

Enhances the pre-commit job by adding flags for increased verbosity, displaying diffs on failure, and forcing color output.

This aids in debugging and understanding pre-commit failures in the CI pipeline.
- Updates CI and migrates to OpenTofu

Refactors the CI configuration to use OpenTofu, providing
improved infrastructure management.

Configures entrypoints for both the main ToFu image and the
tflint image, ensuring proper execution of Terraform tasks.

Updates the tflint image and adds the chdir option to ensure
that linters execute in the correct directory.
- Updates CI configuration and migrates to OpenTofu

Refactors CI configuration, migrates to OpenTofu, and updates tooling versions.
This change enhances the CI pipeline's reliability and efficiency.

It includes updates to various tools, such as tflint and opentofu,
and modifies pre-commit configurations to leverage mise.
The migration to OpenTofu and Ubuntu 24.04 aims to improve
compatibility and maintainability.
- Refactors CI config and adds entrypoint to ToFu image

Removes redundant environment variables for GITHUB_TOKEN in the CI configuration, as they are no longer needed.

Adds an entrypoint to the OpenTofu image in the release configuration to ensure proper execution of scripts.
- Configures entrypoint for tflint image

Adds an entrypoint configuration to the tflint image definition.

This ensures proper execution of the linter within the GitLab CI environment.
- Updates tflint image and adds chdir option

Updates the tflint image version to a specific version to ensure consistent linting.

Adds the `--chdir` option to the tflint command to specify the working directory, ensuring that tflint correctly identifies and lints Terraform files within the project.
- Adds GH_TOKEN for mise authentication

Adds GH_TOKEN environment variable to pre-commit job for mise authentication.

This ensures that mise can properly authenticate with GitHub using either GITHUB_TOKEN or GH_TOKEN.
- Exposes GITHUB_TOKEN to pre-commit jobs

Allows mise to automatically use the GITHUB_TOKEN for pre-commit jobs, enabling access to GitHub resources.
- Adds python3 to pre-commit image

Ensures that the pre-commit job has python3 available.
This resolves issues where pre-commit hooks require python3.
- Removes unused tool versions

Removes versions for tools that are no longer in use, reducing clutter in the configuration file.
- Updates opentofu to v1.11

Updates the opentofu version used in the validation stage and mise configuration.

This ensures the project utilizes the latest features, improvements, and security patches provided by the new opentofu version.
- Migrates to OpenTofu and Ubuntu 24.04

Updates the CI configuration to use OpenTofu for infrastructure validation and Ubuntu 24.04 as the base image for pre-commit checks.

This migration ensures compatibility with the latest infrastructure-as-code tools and provides an up-to-date environment for static code analysis.
- Adds validate stage to pre-commit job

Configures the pre-commit job to run during the
validate stage in the CI/CD pipeline. This ensures
code quality checks are performed early in the
process.
- Improves pre-commit configuration and adds OSV scanning

Updates the pre-commit configuration to use a dedicated Python image and installs necessary dependencies, including the OSV scanner.

Adds OSV scanning to the pre-commit job to identify vulnerabilities.

Uses specific osv-scanner version and fixes the skipping logic.
- first commit

