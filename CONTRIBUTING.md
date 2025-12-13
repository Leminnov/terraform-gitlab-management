# Contributing to GitLab Terraform Module

Thank you for considering contributing to this project!

## Development Setup

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.10.7
- [pre-commit](https://pre-commit.com/) for code quality checks
- [terraform-docs](https://terraform-docs.io/) for documentation generation
- [tflint](https://github.com/terraform-linters/tflint) for linting

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd terraform-modules-gitlab
```

2. Install pre-commit hooks
```bash
pre-commit install --install-hooks
```

3. Initialize Terraform
```bash
terraform init
```

## Development Workflow

### Before Committing

All commits are automatically validated by pre-commit hooks. These hooks will:
- Format Terraform code
- Validate Terraform syntax
- Run TFLint
- Generate documentation
- Check for trailing whitespace
- Detect private keys
- Check YAML/JSON syntax

### Making Changes

1. Create a feature branch
```bash
git checkout -b feature/your-feature-name
```

2. Make your changes
3. Test your changes
```bash
terraform validate
terraform fmt -check -recursive
```

4. Commit your changes (pre-commit hooks will run automatically)
```bash
git add .
git commit -m "feat: description of your changes"
```

5. Push and create a merge request

### Commit Message Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `refactor:` Code refactoring
- `test:` Adding or updating tests
- `chore:` Maintenance tasks

### Testing

Before submitting a merge request:

1. Ensure all pre-commit hooks pass
2. Run `terraform validate` successfully
3. Update examples if adding new features
4. Update README.md documentation if needed

## Release Process

Releases are managed using semantic versioning:

```bash
make changelog  # Generate changelog
make release    # Create release tag
```

## Questions?

Feel free to open an issue for any questions or concerns.
