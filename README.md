# Region 20 ESC Infrastructure

## Setup & Development

### Prerequisites: mise + uv

This project uses [mise](https://mise.jdx.dev/getting-started.html) for task orchestration and [uv](https://docs.astral.sh/uv/getting-started/installation/) for Python environment management.

This keeps tool versioning consistent across all developers and allows cross-os compatibility where possible.

After installing both tools, trust the project config to enable environment interpolation and plugin resolution:

```bash
mise trust              # trust mise.toml (once per machine)
mise trust -a           # trust all mise.toml files in tree
mise trust --show       # check trust status
```

Then we can have mise setup managed versions of everyones tooling to ensure consistency. This includes pre-commit, which we use for git hooks.

```bash
mise install 
mise run setup
```

### Development Commands

```bash
uvx ruff check .              # lint
uvx ruff check . --fix        # auto-fix lint issues
pre-commit run --all-files    # run all hooks manually
mise run trufflehog-scan      # scan for secrets
```

### Conventional Commits
Please use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) for commit messages. This enables automated changelog generation and semantic versioning.

Please try to keep commits atomic and focused on a single change. If commits end up large, please include details in the description to help reviewers.

## Github Actions Workflows

For detailed documentation on the current CICD pipelines for Terraform stacks and Docker builds, please reference the [Github actions documentation](./docs/README.md)
