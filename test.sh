#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test results
print_test() {
    local test_name=$1
    local status=$2

    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        ((TESTS_FAILED++))
    fi
}

echo "========================================="
echo "Running tests for hugging-repo action"
echo "========================================="
echo ""

# Test 1: Check if push.sh exists and is executable
echo "Test 1: Checking if push.sh exists..."
if [ -f "push.sh" ]; then
    print_test "push.sh exists" "PASS"
else
    print_test "push.sh exists" "FAIL"
fi

# Test 2: Check if push.sh has execute permissions
echo "Test 2: Checking if push.sh is executable..."
if [ -x "push.sh" ]; then
    print_test "push.sh is executable" "PASS"
else
    print_test "push.sh is executable" "FAIL"
    chmod +x push.sh
    echo -e "${YELLOW}  → Fixed: Added execute permission${NC}"
fi

# Test 3: Check for required dependencies
echo "Test 3: Checking required dependencies..."

check_dependency() {
    local cmd=$1
    if command -v "$cmd" &> /dev/null; then
        print_test "$cmd is installed" "PASS"
    else
        print_test "$cmd is installed" "FAIL"
    fi
}

check_dependency "curl"
check_dependency "jq"
check_dependency "git"

# Test 4: Validate script syntax
echo "Test 4: Validating Bash syntax..."
if bash -n push.sh 2>/dev/null; then
    print_test "Bash syntax is valid" "PASS"
else
    print_test "Bash syntax is valid" "FAIL"
fi

# Test 5: Test missing required parameters
echo "Test 5: Testing error handling for missing parameters..."

# Test missing token
if ./push.sh --github_repo "test/repo" 2>&1 | grep -q "Error: --token is required"; then
    print_test "Missing token error handling" "PASS"
else
    print_test "Missing token error handling" "FAIL"
fi

# Test missing github_repo
if ./push.sh --token "test_token" 2>&1 | grep -q "Error: --github_repo is required"; then
    print_test "Missing github_repo error handling" "PASS"
else
    print_test "Missing github_repo error handling" "FAIL"
fi

# Test 6: Test unknown option handling
echo "Test 6: Testing unknown option handling..."
if ./push.sh --unknown_option "value" 2>&1 | grep -q "Unknown option"; then
    print_test "Unknown option error handling" "PASS"
else
    print_test "Unknown option error handling" "FAIL"
fi

# Test 7: Validate action.yml syntax
echo "Test 7: Validating action.yml..."
if [ -f "action.yml" ]; then
    # Check if required fields exist
    if grep -q "name:" action.yml && \
       grep -q "description:" action.yml && \
       grep -q "inputs:" action.yml && \
       grep -q "runs:" action.yml; then
        print_test "action.yml has required fields" "PASS"
    else
        print_test "action.yml has required fields" "FAIL"
    fi

    # Check if required inputs are defined
    if grep -q "huggingface_repo:" action.yml && \
       grep -q "hf_token:" action.yml; then
        print_test "action.yml has required inputs" "PASS"
    else
        print_test "action.yml has required inputs" "FAIL"
    fi
else
    print_test "action.yml exists" "FAIL"
fi

# Test 8: Check README exists
echo "Test 8: Checking documentation..."
if [ -f "README.md" ]; then
    print_test "README.md exists" "PASS"
else
    print_test "README.md exists" "FAIL"
fi

# Test 9: Validate shellcheck (if available)
echo "Test 9: Running shellcheck (if available)..."
if command -v shellcheck &> /dev/null; then
    if shellcheck push.sh 2>&1 | grep -q "SC"; then
        echo -e "${YELLOW}  → Warning: shellcheck found issues${NC}"
        print_test "shellcheck analysis" "FAIL"
    else
        print_test "shellcheck analysis" "PASS"
    fi
else
    echo -e "${YELLOW}  → Skipped: shellcheck not installed${NC}"
fi

# Test 10: Test default values
echo "Test 10: Testing default values..."

# Create temporary test directory structure
TEST_DIR=$(mktemp -d)
mkdir -p "$TEST_DIR/work/test-repo/test-repo"
echo "test" > "$TEST_DIR/work/test-repo/test-repo/README.md"

# Test with minimal parameters (should use defaults)
# This will fail at API call but we can check if defaults are set
OUTPUT=$(cd "$TEST_DIR" && /bin/bash -c "
    set +e
    SCRIPT_DIR='$PWD'
    cd '$TEST_DIR'
    '$SCRIPT_DIR/push.sh' --token 'test_token' --github_repo 'test/test-repo' 2>&1
" || true)

if echo "$OUTPUT" | grep -q "Syncing with Hugging Face"; then
    print_test "Script executes with minimal parameters" "PASS"
else
    print_test "Script executes with minimal parameters" "FAIL"
fi

# Cleanup
rm -rf "$TEST_DIR"

# Test 11: Test huggingface_repo parameter variations
echo "Test 11: Testing huggingface_repo parameter handling..."

# Test with namespace included
TEST_DIR=$(mktemp -d)
mkdir -p "$TEST_DIR/work/test-repo/test-repo"
echo "test" > "$TEST_DIR/work/test-repo/test-repo/README.md"

OUTPUT=$(cd "$TEST_DIR" && /bin/bash -c "
    set +e
    SCRIPT_DIR='$PWD'
    cd '$TEST_DIR'
    '$SCRIPT_DIR/push.sh' --token 'test_token' --github_repo 'test/test-repo' --huggingface_repo 'user/my-repo' 2>&1
" || true)

if echo "$OUTPUT" | grep -q "Repo ID: user/my-repo"; then
    print_test "Namespace in huggingface_repo preserved" "PASS"
else
    print_test "Namespace in huggingface_repo preserved" "FAIL"
fi

rm -rf "$TEST_DIR"

# Test 12: Test repo_type parameter
echo "Test 12: Testing repo_type parameter..."

for repo_type in "space" "model" "dataset"; do
    TEST_DIR=$(mktemp -d)
    mkdir -p "$TEST_DIR/work/test-repo/test-repo"
    echo "test" > "$TEST_DIR/work/test-repo/test-repo/README.md"

    OUTPUT=$(cd "$TEST_DIR" && /bin/bash -c "
        set +e
        SCRIPT_DIR='$PWD'
        cd '$TEST_DIR'
        '$SCRIPT_DIR/push.sh' --token 'test_token' --github_repo 'test/test-repo' --repo_type '$repo_type' 2>&1
    " || true)

    if echo "$OUTPUT" | grep -q "Syncing with Hugging Face"; then
        print_test "repo_type=$repo_type accepted" "PASS"
    else
        print_test "repo_type=$repo_type accepted" "FAIL"
    fi

    rm -rf "$TEST_DIR"
done

# Test 13: Test space_sdk parameter
echo "Test 13: Testing space_sdk parameter..."

for sdk in "gradio" "streamlit" "static"; do
    TEST_DIR=$(mktemp -d)
    mkdir -p "$TEST_DIR/work/test-repo/test-repo"
    echo "test" > "$TEST_DIR/work/test-repo/test-repo/README.md"

    OUTPUT=$(cd "$TEST_DIR" && /bin/bash -c "
        set +e
        SCRIPT_DIR='$PWD'
        cd '$TEST_DIR'
        '$SCRIPT_DIR/push.sh' --token 'test_token' --github_repo 'test/test-repo' --space_sdk '$sdk' 2>&1
    " || true)

    if echo "$OUTPUT" | grep -q "Syncing with Hugging Face"; then
        print_test "space_sdk=$sdk accepted" "PASS"
    else
        print_test "space_sdk=$sdk accepted" "FAIL"
    fi

    rm -rf "$TEST_DIR"
done

# Test 14: Test private parameter
echo "Test 14: Testing private parameter..."

for private_val in "true" "false"; do
    TEST_DIR=$(mktemp -d)
    mkdir -p "$TEST_DIR/work/test-repo/test-repo"
    echo "test" > "$TEST_DIR/work/test-repo/test-repo/README.md"

    OUTPUT=$(cd "$TEST_DIR" && /bin/bash -c "
        set +e
        SCRIPT_DIR='$PWD'
        cd '$TEST_DIR'
        '$SCRIPT_DIR/push.sh' --token 'test_token' --github_repo 'test/test-repo' --private '$private_val' 2>&1
    " || true)

    if echo "$OUTPUT" | grep -q "Syncing with Hugging Face"; then
        print_test "private=$private_val accepted" "PASS"
    else
        print_test "private=$private_val accepted" "FAIL"
    fi

    rm -rf "$TEST_DIR"
done

# Test 15: Test same_with_github_repo special value
echo "Test 15: Testing same_with_github_repo special value..."

TEST_DIR=$(mktemp -d)
mkdir -p "$TEST_DIR/work/test-repo/test-repo"
echo "test" > "$TEST_DIR/work/test-repo/test-repo/README.md"

OUTPUT=$(cd "$TEST_DIR" && /bin/bash -c "
    set +e
    SCRIPT_DIR='$PWD'
    cd '$TEST_DIR'
    '$SCRIPT_DIR/push.sh' --token 'test_token' --github_repo 'owner/test-repo' --huggingface_repo 'same_with_github_repo' 2>&1
" || true)

if echo "$OUTPUT" | grep -q "owner/test-repo"; then
    print_test "same_with_github_repo handled correctly" "PASS"
else
    print_test "same_with_github_repo handled correctly" "FAIL"
fi

rm -rf "$TEST_DIR"

# Test 16: Test missing work directory
echo "Test 16: Testing missing work directory error..."

TEST_DIR=$(mktemp -d)
# Don't create work directory

OUTPUT=$(cd "$TEST_DIR" && /bin/bash -c "
    set +e
    SCRIPT_DIR='$PWD'
    cd '$TEST_DIR'
    '$SCRIPT_DIR/push.sh' --token 'test_token' --github_repo 'test/test-repo' 2>&1
" || true)

if echo "$OUTPUT" | grep -q "Error: Directory .* does not exist"; then
    print_test "Missing directory error handling" "PASS"
else
    print_test "Missing directory error handling" "FAIL"
fi

rm -rf "$TEST_DIR"

# Test 17: Check if all required inputs from action.yml are handled in push.sh
echo "Test 17: Validating action.yml and push.sh consistency..."

# Extract inputs from action.yml
if grep -q "huggingface_repo:" action.yml && \
   grep -q "hf_token:" action.yml && \
   grep -q "repo_type:" action.yml && \
   grep -q "space_sdk:" action.yml && \
   grep -q "private:" action.yml; then

    # Check if push.sh handles all these parameters
    if grep -q "HUGGINGFACE_REPO" push.sh && \
       grep -q "HF_TOKEN" push.sh && \
       grep -q "REPO_TYPE" push.sh && \
       grep -q "SPACE_SDK" push.sh && \
       grep -q "PRIVATE" push.sh; then
        print_test "action.yml inputs match push.sh parameters" "PASS"
    else
        print_test "action.yml inputs match push.sh parameters" "FAIL"
    fi
else
    print_test "action.yml has all expected inputs" "FAIL"
fi

# Summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
