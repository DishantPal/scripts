#!/bin/bash

print_header() {
    echo -e "\n\033[1;34m=== $1 ===\033[0m"
}

print_header "GitHub Deploy Key Updater"

# 1. Gather Input
read -p "Enter Repository (e.g., username/repo): " REPO_SLUG < /dev/tty
read -p "Enter GitHub Access Token: " GH_TOKEN < /dev/tty

if [[ -z "$REPO_SLUG" || -z "$GH_TOKEN" ]]; then
    echo "❌ Error: Repo and Token are required."
    exit 1
fi

# 2. List existing deploy keys
print_header "Fetching Existing Deploy Keys"

KEYS_RESPONSE=$(curl -L \
  -X GET \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$REPO_SLUG/keys" \
  -s -w "\n%{http_code}")

HTTP_CODE=$(echo "$KEYS_RESPONSE" | tail -n1)
BODY=$(echo "$KEYS_RESPONSE" | head -n -1)

if [ "$HTTP_CODE" -ne 200 ]; then
    echo "❌ Failed to fetch keys (HTTP $HTTP_CODE)."
    echo "Error: $BODY"
    unset GH_TOKEN
    exit 1
fi

# Parse and display keys
KEY_COUNT=$(echo "$BODY" | grep -o '"id":' | wc -l)

if [ "$KEY_COUNT" -eq 0 ]; then
    echo "⚠️  No deploy keys found for $REPO_SLUG."
    unset GH_TOKEN
    exit 1
fi

echo ""
echo "Found $KEY_COUNT deploy key(s):"
echo ""

# Display each key with index
IDS=()
TITLES=()
READ_ONLYS=()

while IFS= read -r line; do
    IDS+=("$line")
done < <(echo "$BODY" | grep -o '"id": *[0-9]*' | grep -o '[0-9]*')

while IFS= read -r line; do
    TITLES+=("$line")
done < <(echo "$BODY" | python3 -c "
import sys, json
keys = json.load(sys.stdin)
for k in keys:
    print(k.get('title','(no title)'))
")

while IFS= read -r line; do
    READ_ONLYS+=("$line")
done < <(echo "$BODY" | python3 -c "
import sys, json
keys = json.load(sys.stdin)
for k in keys:
    print('Read-Only' if k.get('read_only') else 'Read-Write')
")

for i in "${!IDS[@]}"; do
    echo "  [$((i+1))] ID: ${IDS[$i]} | Title: ${TITLES[$i]} | Access: ${READ_ONLYS[$i]}"
done

echo ""
read -p "Enter the number of the key to update: " KEY_INDEX < /dev/tty

# Validate selection
if ! [[ "$KEY_INDEX" =~ ^[0-9]+$ ]] || [ "$KEY_INDEX" -lt 1 ] || [ "$KEY_INDEX" -gt "$KEY_COUNT" ]; then
    echo "❌ Invalid selection."
    unset GH_TOKEN
    exit 1
fi

SELECTED_ID="${IDS[$((KEY_INDEX-1))]}"
SELECTED_TITLE="${TITLES[$((KEY_INDEX-1))]}"

echo "✅ Selected: $SELECTED_TITLE (ID: $SELECTED_ID)"

# 3. Ask what to update
print_header "Update Options"

read -p "New key title (leave blank to keep '$SELECTED_TITLE'): " NEW_TITLE < /dev/tty
NEW_TITLE="${NEW_TITLE:-$SELECTED_TITLE}"

read -p "Enable Write Access (allow git push)? (y/N): " WRITE_INPUT < /dev/tty
if [[ "$WRITE_INPUT" =~ ^[Yy]$ ]]; then
    READ_ONLY_BOOL="false"
    echo "ℹ️  Key will have WRITE access."
else
    READ_ONLY_BOOL="true"
    echo "ℹ️  Key will be READ-ONLY."
fi

# 4. Determine SSH key to use
print_header "SSH Key"

# Derive a default key name from the title (lowercase, spaces→dashes, strip special chars)
DEFAULT_KEY_NAME=$(echo "$NEW_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')
KEY_PATH="$HOME/.ssh/$DEFAULT_KEY_NAME"

read -p "SSH key file path (leave blank to use/generate '$KEY_PATH'): " CUSTOM_PATH < /dev/tty
[ -n "$CUSTOM_PATH" ] && KEY_PATH="$CUSTOM_PATH"

if [ -f "$KEY_PATH" ]; then
    read -p "Key file '$KEY_PATH' exists. Regenerate it? (y/N): " REGEN_INPUT < /dev/tty
    if [[ "$REGEN_INPUT" =~ ^[Yy]$ ]]; then
        rm -f "$KEY_PATH" "$KEY_PATH.pub"
        ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "deploy-key-$DEFAULT_KEY_NAME" > /dev/null 2>&1
        echo "✅ Regenerated SSH key: $KEY_PATH"
    else
        echo "ℹ️  Using existing key: $KEY_PATH"
    fi
else
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "deploy-key-$DEFAULT_KEY_NAME" > /dev/null 2>&1
    echo "✅ Generated new SSH key: $KEY_PATH"
fi

# 5. Delete old key from GitHub
print_header "Removing Old Key from GitHub"

DEL_RESPONSE=$(curl -L \
  -X DELETE \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$REPO_SLUG/keys/$SELECTED_ID" \
  -s -w "\n%{http_code}")

DEL_CODE=$(echo "$DEL_RESPONSE" | tail -n1)

if [ "$DEL_CODE" -ne 204 ]; then
    echo "❌ Failed to delete old key (HTTP $DEL_CODE)."
    echo "$(echo "$DEL_RESPONSE" | head -n -1)"
    unset GH_TOKEN
    exit 1
fi

echo "✅ Old key deleted from GitHub."

# 6. Upload new key
print_header "Uploading New Key to GitHub"

ADD_RESPONSE=$(curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$REPO_SLUG/keys" \
  -d "{\"title\":\"$NEW_TITLE\",\"key\":\"$(cat "$KEY_PATH.pub")\",\"read_only\":$READ_ONLY_BOOL}" \
  -s -w "\n%{http_code}")

ADD_CODE=$(echo "$ADD_RESPONSE" | tail -n1)
ADD_BODY=$(echo "$ADD_RESPONSE" | head -n -1)

unset GH_TOKEN

if [ "$ADD_CODE" -eq 201 ]; then
    echo "✅ New key uploaded to GitHub successfully."

    print_header "Next Steps"
    echo "To use this key:"
    echo "  GIT_SSH_COMMAND='ssh -i $KEY_PATH' git clone git@github.com:$REPO_SLUG.git"

    if [ "$READ_ONLY_BOOL" == "false" ]; then
        echo ""
        echo "💡 Tip: Since you enabled write access, add this to ~/.ssh/config for automatic use:"
        echo ""
        echo "  Host github-$DEFAULT_KEY_NAME"
        echo "      HostName github.com"
        echo "      IdentityFile $KEY_PATH"
        echo "      User git"
    fi
else
    echo "❌ Failed to upload new key (HTTP $ADD_CODE)."
    echo "Error: $ADD_BODY"
    echo ""
    echo "⚠️  Warning: The old key was already deleted. Run the setup script to add a new key."
    exit 1
fi
