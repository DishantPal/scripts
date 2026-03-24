# Setup GitHub Deploy Key

Automates SSH deploy key generation and registration with a GitHub repository. Run this on any server (VPS, CI box) that needs Git access to a specific repo.

## Prerequisites

- `ssh-keygen` and `curl` (pre-installed on most Linux/macOS systems)
- A GitHub **Personal Access Token** with `Administration: Read & Write` permission on the target repo
  - GitHub → Settings → Developer Settings → Fine-grained Tokens → Generate

## Usage

```bash
# Download and run
curl -sL https://raw.githubusercontent.com/DishantPal/scripts/master/setup-github-deploy-key/script.sh | bash

# Or clone and run
git clone https://github.com/DishantPal/scripts.git
cd scripts/setup-github-deploy-key
chmod +x script.sh
./script.sh
```

You'll be prompted for:

| Prompt | Example | Description |
|--------|---------|-------------|
| Key Name | `vps-prod` | Used as filename under `~/.ssh/` |
| Repository | `username/repo` | GitHub repo in `owner/repo` format |
| Access Token | `github_pat_...` | Fine-grained token (cleared from memory after use) |
| Write Access | `y` or `N` | Whether the key can push (default: read-only) |

## What It Does

1. Generates an `ed25519` SSH key pair at `~/.ssh/<key-name>`
2. Uploads the **public** key to the repo via GitHub API
3. Clears the token from shell memory
4. Prints a ready-to-use clone command

## After Setup

Use the key immediately with:

```bash
GIT_SSH_COMMAND='ssh -i ~/.ssh/<key-name>' git clone git@github.com:owner/repo.git
```

Or add to `~/.ssh/config` for automatic usage:

```
Host github-<key-name>
    HostName github.com
    User git
    IdentityFile ~/.ssh/<key-name>
    IdentitiesOnly yes
```

Then clone with:

```bash
git clone github-<key-name>:owner/repo.git
```

## Notes

- Deploy keys are **repo-scoped** — one key per repo (more secure than user-wide SSH keys)
- The private key never leaves the server; only the public key is uploaded to GitHub
- If a key file already exists at `~/.ssh/<key-name>`, generation is skipped
- Token is `unset` from the shell after the API call