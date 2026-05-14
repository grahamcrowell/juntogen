#!/usr/bin/env bash
#
# validate-primitive.sh - Validation script for claude CLI primitive
#
# PURPOSE: Validate that `claude --print --append-system-prompt` can inject
#          CLAUDE.md as system context for future Tier B validation.
#
# SCOPE: Validates the primitive. Does NOT implement
#                  full Tier B validation infrastructure.
#
# EXIT CODES:
#   0 - Validation successful (primitive works as expected)
#   1 - claude CLI not found or not in PATH
#   2 - Test file creation failed
#   3 - claude invocation failed
#   4 - Output validation failed

set -euo pipefail

# Color output for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check if claude CLI is available
if ! command -v claude &> /dev/null; then
    log_error "claude CLI not found in PATH"
    log_error "Install with: npm install -g @anthropics/claude-code"
    exit 1
fi

log_info "claude CLI found: $(command -v claude)"

# Create a minimal test CLAUDE.md for validation
TEST_DIR=$(mktemp -d)
TEST_CLAUDE_MD="${TEST_DIR}/CLAUDE.md"
TEST_OUTPUT="${TEST_DIR}/output.txt"

trap 'rm -rf "${TEST_DIR}"' EXIT

log_info "Creating test CLAUDE.md at ${TEST_CLAUDE_MD}"

cat > "${TEST_CLAUDE_MD}" <<'EOF'
# Test CLAUDE.md for generate.sh validation

You are a test validation agent. When you receive the prompt "VALIDATION_TEST",
respond with exactly: "VALIDATION_SUCCESS: claude --append-system-prompt works"
EOF

if [[ ! -f "${TEST_CLAUDE_MD}" ]]; then
    log_error "Failed to create test CLAUDE.md"
    exit 2
fi

log_info "Test CLAUDE.md created successfully"

# Test the claude CLI primitive
log_info "Testing: claude --print --append-system-prompt"

if ! claude --print --append-system-prompt "${TEST_CLAUDE_MD}" "VALIDATION_TEST" > "${TEST_OUTPUT}" 2>&1; then
    log_error "claude invocation failed"
    log_error "Output:"
    cat "${TEST_OUTPUT}"
    exit 3
fi

log_info "claude invocation successful"

# Validate output structure
log_info "Validating output..."

if grep -q "VALIDATION_SUCCESS" "${TEST_OUTPUT}"; then
    log_info "Output validation PASSED"
    log_info "Primitive confirmed working: claude --append-system-prompt can inject CLAUDE.md context"
    echo ""
    log_info "Full output:"
    cat "${TEST_OUTPUT}"
    exit 0
else
    log_warn "Expected validation marker not found in output"
    log_info "Output received:"
    cat "${TEST_OUTPUT}"
    log_warn "Primitive may work differently than expected - review output above"
    exit 4
fi
