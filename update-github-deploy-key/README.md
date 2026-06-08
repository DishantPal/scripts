# Update GitHub Deploy Key

Rotates an existing deploy key on a GitHub repository — lists all current keys, lets you pick one to replace, optionally regenerates the local SSH key pair, then swaps it on GitHub atomically (delete old → upload new).

## Prerequisites

- `ssh-keygen`, `curl`, and `python3` (pre-installed on most Linux/macOS systems)
- A GitHub **Personal Access Token** with `Administration: Read & Write` permission on the target repo
  - GitHub → Settings → Developer Settings → Fine-grained Tokens → Generate

## Usage

```bash
# Download and run
curl -sL https://raw.githubusercontent.com/DishantPal/scripts/master/update-github-deploy-key/script.sh | bash

# Or clone and run
git clone https://github.com/DishantPal/scripts.git
cd scripts/update-github-deploy-key
chmod +x script.sh
./script.sh
```

You'll be prompted for:

| Prompt | Example | Description |
|--------|---------|-------------|
| Repository | `username/repo` | GitHub repo in `owner/repo` format |
| Access Token | `github_pat_...` | Fine-grained token (cleared from memory after use) |
| Key to update | `1` | Number from the displayed list of existing keys |
| New title | `vps-prod-2026` | Leave blank to keep the existing title |
| Write Access | `y` or `N` | Whether the new key can push (default: read-only) |
| SSH key path | `~/.ssh/vps-prod` | Leave blank to auto-derive from title |
| Regenerate key | `y` or `N` | Whether to regenerate the local key pair |

## What It Does

1. Fetches and displays all deploy keys for the repo
2. Lets you select which key to replace
3. Prompts for the new title, access level, and key file path
4. Optionally regenerates the `ed25519` SSH key pair on disk
5. Deletes the old key from GitHub
6. Uploads the new public key to GitHub
7. Clears the token from shell memory

## After Update

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

## Notes

- GitHub does not support editing a deploy key in place — this script deletes and recreates it
- If the upload step fails after deletion, the script warns you and suggests re-running the setup script
- The private key never leaves the server; only the public key is sent to GitHub
- Token is `unset` from the shell immediately after the API calls complete
