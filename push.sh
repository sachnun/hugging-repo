#!/bin/bash

set -e

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --hf_repo)
            HF_REPO="$2"
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
PRIVATE=${PRIVATE:-"false"}

echo "Syncing with Hugging Face Spaces..."

# Handle hf_repo name
if [ "$HF_REPO" = "same_with_github_repo" ]; then
    HF_REPO="$GITHUB_REPO"
fi

# Get username if namespace is implicit
if [[ ! "$HF_REPO" =~ "/" ]]; then
    echo -e "\t- Getting username from Hugging Face..."
    USERNAME=$(curl -s -X GET "https://huggingface.co/api/whoami-v2" \
        -H "Authorization: Bearer $HF_TOKEN" | jq -r '.name')

    if [ -z "$USERNAME" ] || [ "$USERNAME" = "null" ]; then
        echo "Error: Failed to get username from Hugging Face"
        exit 1
    fi

    HF_REPO="$USERNAME/$HF_REPO"
fi

echo -e "\t- Repo ID: $HF_REPO"
echo -e "\t- Github_repo: $GITHUB_REPO"

# Determine directory path for auto-detection
LATTER_REPO=$(echo "$GITHUB_REPO" | cut -d'/' -f2)
DIRECTORY="work/$LATTER_REPO/$LATTER_REPO"

# If work directory doesn't exist, use current directory
if [ ! -d "$DIRECTORY" ]; then
    DIRECTORY="."
    echo -e "\t- Using current directory"
fi

# Auto-detect space_sdk if not set and repo_type is space
if [ "$REPO_TYPE" = "space" ] && [ -z "$SPACE_SDK" ]; then
    if [ -f "$DIRECTORY/Dockerfile" ]; then
        SPACE_SDK="docker"
        echo -e "\t- Auto-detected space_sdk: docker (Dockerfile found)"
    else
        SPACE_SDK="gradio"
        echo -e "\t- Auto-detected space_sdk: gradio (default)"
    fi
else
    SPACE_SDK=${SPACE_SDK:-"gradio"}
fi

# Create repository
echo -e "\t- Creating repository..."

# Extract repo name (without namespace) for API call
REPO_NAME=$(echo "$HF_REPO" | cut -d'/' -f2)

# Prepare JSON payload
if [ "$REPO_TYPE" = "space" ]; then
    JSON_PAYLOAD=$(jq -n \
        --arg name "$REPO_NAME" \
        --arg type "$REPO_TYPE" \
        --arg sdk "$SPACE_SDK" \
        --argjson private "$([ "$PRIVATE" = "true" ] && echo true || echo false)" \
        '{name: $name, type: $type, sdk: $sdk, private: $private}')
else
    JSON_PAYLOAD=$(jq -n \
        --arg name "$REPO_NAME" \
        --arg type "$REPO_TYPE" \
        --argjson private "$([ "$PRIVATE" = "true" ] && echo true || echo false)" \
        '{name: $name, type: $type, private: $private}')
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
    # Construct repo URL based on type
    case "$REPO_TYPE" in
        space)
            REPO_URL="https://huggingface.co/spaces/$HF_REPO"
            ;;
        model)
            REPO_URL="https://huggingface.co/$HF_REPO"
            ;;
        dataset)
            REPO_URL="https://huggingface.co/datasets/$HF_REPO"
            ;;
    esac
    echo -e "\t- Repo URL: $REPO_URL"
else
    echo "Error creating repository. HTTP Code: $HTTP_CODE"
    echo "Response: $RESPONSE_BODY"
    exit 1
fi

# Check if directory exists

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
# Construct repo URL based on type
case "$REPO_TYPE" in
    space)
        REMOTE_URL="https://user:${HF_TOKEN}@huggingface.co/spaces/$HF_REPO"
        ;;
    model)
        REMOTE_URL="https://user:${HF_TOKEN}@huggingface.co/$HF_REPO"
        ;;
    dataset)
        REMOTE_URL="https://user:${HF_TOKEN}@huggingface.co/datasets/$HF_REPO"
        ;;
    *)
        echo "Error: Unknown repo_type: $REPO_TYPE"
        exit 1
        ;;
esac

git remote add space "$REMOTE_URL" 2>/dev/null || \
    git remote set-url space "$REMOTE_URL"

# Force push to Hugging Face
git push --force space main

COMMIT_URL="$REPO_URL/tree/main"
echo -e "\t- Repo synced: $COMMIT_URL"

echo "✅ Sync completed successfully!"
