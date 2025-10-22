#!/bin/bash

set -e

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --huggingface_repo)
            HUGGINGFACE_REPO="$2"
            shift 2
            ;;
        --github_repo)
            GITHUB_REPO="$2"
            shift 2
            ;;
        --token)
            HF_TOKEN="$2"
            shift 2
            ;;
        --repo_type)
            REPO_TYPE="$2"
            shift 2
            ;;
        --space_sdk)
            SPACE_SDK="$2"
            shift 2
            ;;
        --private)
            PRIVATE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$HF_TOKEN" ]; then
    echo "Error: --token is required"
    exit 1
fi

if [ -z "$GITHUB_REPO" ]; then
    echo "Error: --github_repo is required"
    exit 1
fi

# Set defaults
REPO_TYPE=${REPO_TYPE:-"space"}
SPACE_SDK=${SPACE_SDK:-"gradio"}
PRIVATE=${PRIVATE:-"false"}

echo "Syncing with Hugging Face Spaces..."

# Handle huggingface_repo name
if [ "$HUGGINGFACE_REPO" = "same_with_github_repo" ]; then
    HUGGINGFACE_REPO="$GITHUB_REPO"
fi

# Get username if namespace is implicit
if [[ ! "$HUGGINGFACE_REPO" =~ "/" ]]; then
    echo -e "\t- Getting username from Hugging Face..."
    USERNAME=$(curl -s -X GET "https://huggingface.co/api/whoami-v2" \
        -H "Authorization: Bearer $HF_TOKEN" | jq -r '.name')

    if [ -z "$USERNAME" ] || [ "$USERNAME" = "null" ]; then
        echo "Error: Failed to get username from Hugging Face"
        exit 1
    fi

    HUGGINGFACE_REPO="$USERNAME/$HUGGINGFACE_REPO"
fi

echo -e "\t- Repo ID: $HUGGINGFACE_REPO"
echo -e "\t- Github_repo: $GITHUB_REPO"

# Create repository
echo -e "\t- Creating repository..."

# Prepare JSON payload
if [ "$REPO_TYPE" = "space" ]; then
    JSON_PAYLOAD=$(jq -n \
        --arg type "$REPO_TYPE" \
        --arg sdk "$SPACE_SDK" \
        --argjson private "$([ "$PRIVATE" = "true" ] && echo true || echo false)" \
        '{type: $type, sdk: $sdk, private: $private}')
else
    JSON_PAYLOAD=$(jq -n \
        --arg type "$REPO_TYPE" \
        --argjson private "$([ "$PRIVATE" = "true" ] && echo true || echo false)" \
        '{type: $type, private: $private}')
fi

CREATE_RESPONSE=$(curl -s -X POST "https://huggingface.co/api/repos/create" \
    -H "Authorization: Bearer $HF_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" \
    -w "\n%{http_code}")

HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$CREATE_RESPONSE" | head -n-1)

# Check if repo was created or already exists
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "409" ]; then
    REPO_URL="https://huggingface.co/$HUGGINGFACE_REPO"
    echo -e "\t- Repo URL: $REPO_URL"
else
    echo "Error creating repository. HTTP Code: $HTTP_CODE"
    echo "Response: $RESPONSE_BODY"
    exit 1
fi

# Determine directory path
LATTER_REPO=$(echo "$GITHUB_REPO" | cut -d'/' -f2)
DIRECTORY="work/$LATTER_REPO/$LATTER_REPO"

if [ ! -d "$DIRECTORY" ]; then
    echo "Error: Directory $DIRECTORY does not exist"
    exit 1
fi

echo -e "\t- Uploading files from $DIRECTORY..."

# Initialize git repo if needed and push to Hugging Face
cd "$DIRECTORY"

# Configure git
git config --global user.email "action@github.com"
git config --global user.name "GitHub Action"

# Remove existing git repo if present
if [ -d ".git" ]; then
    rm -rf .git
fi

# Initialize new git repo
git init
git checkout -b main

# Create .gitignore if it doesn't exist
if [ ! -f ".gitignore" ]; then
    cat > .gitignore <<EOF
.git
README.md
EOF
fi

# Add files
git add .

# Check if there are changes to commit
if git diff-index --quiet HEAD -- 2>/dev/null; then
    echo -e "\t- No changes to commit"
else
    # Commit changes
    git commit -m "Synced repo using 'sync_with_huggingface' Github Action" || true
fi

# Add remote and push
git remote add space "https://user:${HF_TOKEN}@huggingface.co/spaces/$HUGGINGFACE_REPO" 2>/dev/null || \
    git remote set-url space "https://user:${HF_TOKEN}@huggingface.co/spaces/$HUGGINGFACE_REPO"

# Force push to Hugging Face
git push --force space main

COMMIT_URL="$REPO_URL/tree/main"
echo -e "\t- Repo synced: $COMMIT_URL"

echo "✅ Sync completed successfully!"
