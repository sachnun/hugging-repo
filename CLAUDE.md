# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**hugging-repo** is a GitHub Action that syncs GitHub repository content to Hugging Face (spaces, models, or datasets). It's implemented entirely in pure Bash with no Python dependencies.

## Architecture

The action consists of two main components:

1. **action.yml** - GitHub Action composite definition that:
   - Checks out the current repository
   - Executes push.sh with configured parameters
   - Defines inputs: huggingface_repo, hf_token (required), repo_type, space_sdk, private

2. **push.sh** - Core Bash script that:
   - Parses command-line arguments
   - Auto-detects space_sdk if not provided (checks for Dockerfile → docker, else gradio)
   - Calls Hugging Face API to get username (if namespace not provided)
   - Creates repository via Hugging Face API (/api/repos/create)
   - Initializes git in the working directory (work/$LATTER_REPO/$LATTER_REPO)
   - Force pushes content to huggingface.co/spaces/

### Key Implementation Details

- **Repository URL construction**: If huggingface_repo doesn't contain "/", the script fetches the username via HF API whoami-v2 endpoint and constructs full namespace/repo format
- **Repository types**: Supports "space" (default), "model", or "dataset"
- **Space SDK types**: For spaces only - "gradio" (default), "streamlit", "static", or "docker"
- **Auto-detection**: If space_sdk is not provided and repo_type is "space", checks for Dockerfile:
  - If Dockerfile exists → uses "docker"
  - Otherwise → uses "gradio" (default)
- **Git workflow**: The script removes any existing .git directory, initializes fresh repo, and force pushes to HF remote
- **Error handling**: Uses `set -e` to exit on any error; validates required parameters (HF_TOKEN, GITHUB_REPO)

## Development Commands

### Testing the Action Locally

To test the push script locally:

```bash
./push.sh \
  --huggingface_repo "my-repo" \
  --github_repo "owner/repo-name" \
  --token "YOUR_HF_TOKEN" \
  --repo_type "space" \
  --space_sdk "gradio" \
  --private "false"
```

Note: The script expects content in `work/repo-name/repo-name` directory structure (GitHub Actions checkout pattern).

### Validating Action Syntax

```bash
# Validate action.yml syntax
cat action.yml | grep -E "(name|description|inputs|runs)" | head -20
```

## Dependencies

- **curl** - For Hugging Face API calls
- **jq** - For JSON processing (building payloads, parsing API responses)
- **git** - For repository operations

## Git Commit Conventions

Always use scoped commits following the format: `scope(component): description`

Examples from this repo:
- `docs(readme): simplify documentation`
- `docs(action): add sachnun as co-author`
- `fix(action): change name to Hugging Repo`

## Notes

- The action is designed to run in GitHub Actions environment where the repository is checked out to a specific work directory path
- The script uses force push (`git push --force`) to ensure content matches exactly
- HTTP status codes 200 (created) and 409 (already exists) are both considered successful for repo creation
