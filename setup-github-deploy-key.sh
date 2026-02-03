#!/bin/bash

# Function to print section headers
print_header() {
    echo -e "\n\033[1;34m=== $1 ===\033[0m"
}

print_header "GitHub Deploy Key Setup"

# 1. Gather Input (Redirecting from /dev/tty to allow piping)
read -p "Enter Key Name (e.g., vps-prod): " KEY_NAME < /dev/tty
read -p "Enter Repository (e.g., username/repo): " REPO_SLUG < /dev/tty
read -p "Enter GitHub Access Token: " GH_TOKEN < /dev/tty

# New Step: Ask for Write Access
read -p "Enable Write Access (allow git push)? (y/N): " WRITE_INPUT < /dev/tty

# Set Read-Only flag based on input
if [[ "$WRITE_INPUT" =~ ^[Yy]$ ]]; then
    READ_ONLY_BOOL="false"
    echo "ℹ️  Key will have WRITE access."
else
    READ_ONLY_BOOL="true"
    echo "ℹ️  Key will be READ-ONLY."
fi

# Validate input
if [[ -z "$KEY_NAME" || -z "$REPO_SLUG" || -z "$GH_TOKEN" ]]; then
    echo "❌ Error: Key Name, Repo, and Token are required."
    exit 1
fi

KEY_PATH="$HOME/.ssh/$KEY_NAME"

# 2. Generate SSH Key
print_header "Generating SSH Key"
if [ -f "$KEY_PATH" ]; then
    echo "⚠️  Key file $KEY_PATH already exists. Skipping generation."
else
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "deploy-key-$KEY_NAME" > /dev/null 2>&1
    echo "✅ Generated SSH key: $KEY_PATH"
fi

# 3. Upload to GitHub
print_header "Uploading to GitHub"

# Note: We insert the $READ_ONLY_BOOL variable into the JSON payload
RESPONSE=$(curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$REPO_SLUG/keys \
  -d "{\"title\":\"VPS Deploy Key ($KEY_NAME)\",\"key\":\"$(cat $KEY_PATH.pub)\",\"read_only\":$READ_ONLY_BOOL}" \
  -s -w "\n%{http_code}")

# Extract status code (last line) and body
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n -1)

# 4. Clean up Token
unset GH_TOKEN

# 5. Check Result
if [ "$HTTP_CODE" -eq 201 ]; then
    echo "✅ Success! Key uploaded to GitHub."
    
    print_header "Next Steps"
    echo "To use this key for cloning/pushing:"
    echo "GIT_SSH_COMMAND='ssh -i $KEY_PATH' git clone git@github.com:$REPO_SLUG.git"
    
    # Suggest configuring SSH config for write access easier usage
    if [ "$READ_ONLY_BOOL" == "false" ]; then
        echo ""
        echo "💡 Tip: Since you enabled write access, configure ~/.ssh/config so 'git push' works automatically without flags."
    fi
else
    echo "❌ Failed (HTTP $HTTP_CODE)."
    echo "Error from GitHub: $BODY"
    exit 1
fi
