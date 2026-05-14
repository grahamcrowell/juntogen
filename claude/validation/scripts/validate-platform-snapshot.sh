#!/usr/bin/env bash
#
# validate-platform-snapshot.sh - Structural assertions for platform-snapshot.yaml
#
# PURPOSE: Validate that a platform snapshot file conforms to the capability
#          schema defined in M16-derivation-architecture.md Section 3 and
#          juntogen/claude/steps/step-00-platform-ingestion.md.
#
# USAGE: ./validate-platform-snapshot.sh [path-to-platform-snapshot.yaml]
#        Defaults to platform-snapshot.yaml in the current directory.
#
# REQUIRES: yq (preferred) or falls back to field-level matching
#
# EXIT CODES:
#   0 - All assertions passed
#   1 - One or more assertions failed
#   2 - Target file not found

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
    echo -e "${GREEN}PASS${NC} $*"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo -e "${RED}FAIL${NC} $*"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
    echo -e "${YELLOW}WARN${NC} $*"
    WARN_COUNT=$((WARN_COUNT + 1))
}

info() {
    echo -e "${YELLOW}[INFO]${NC} $*"
}

# Check for yq availability
HAS_YQ=false
if command -v yq &>/dev/null; then
    HAS_YQ=true
fi

# --- yq helpers (used when yq is available) ---

yq_read() {
    # Read a field from the YAML file using yq
    local file="$1" path="$2"
    yq eval "$path" "$file" 2>/dev/null
}

yq_count() {
    # Count array elements at a path
    local file="$1" path="$2"
    yq eval "$path | length" "$file" 2>/dev/null
}

# --- fallback helpers (field-level matching without yq) ---

fallback_field() {
    # Extract a simple scalar field value via pattern matching
    # Usage: fallback_field file key
    local file="$1" key="$2"
    sed -n "s/^[[:space:]]*${key}:[[:space:]]*\"\{0,1\}\([^\"]*\)\"\{0,1\}[[:space:]]*$/\1/p" "$file" | head -1
}

fallback_count_array_items() {
    # Count top-level items in a YAML array section by counting "- name:" or "- id:" or "- point:" lines
    # Usage: fallback_count_array_items file section_key item_marker
    local file="$1" section_key="$2" item_marker="$3"
    local in_section=false count=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*${section_key}: ]]; then
            in_section=true
            continue
        fi
        if $in_section; then
            # Exit section if we hit a non-indented key
            if [[ "$line" =~ ^[a-zA-Z_] ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
                break
            fi
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*${item_marker}: ]]; then
                count=$((count + 1))
            fi
        fi
    done < "$file"
    echo "$count"
}

fallback_model_has_field() {
    # Check if all model entries have a given field
    # Returns 0 (true) if all models have the field, 1 (false) otherwise
    local file="$1" field="$2"
    local in_models=false model_count=0 field_count=0
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*models: ]]; then
            in_models=true
            continue
        fi
        if $in_models; then
            if [[ "$line" =~ ^[[:space:]]*[a-zA-Z_]+: ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
                break
            fi
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*id: ]]; then
                model_count=$((model_count + 1))
            fi
            if [[ "$line" =~ ^[[:space:]]*${field}: ]]; then
                field_count=$((field_count + 1))
            fi
        fi
    done < "$file"
    [[ "$model_count" -gt 0 ]] && [[ "$model_count" -eq "$field_count" ]]
}

# --- Determine target file ---

TARGET_FILE="${1:-platform-snapshot.yaml}"

if [[ ! -f "${TARGET_FILE}" ]]; then
    echo -e "${RED}ERROR${NC} Target file not found: ${TARGET_FILE}"
    echo "Usage: $0 [path-to-platform-snapshot.yaml]"
    exit 2
fi

info "Running platform snapshot validation against: ${TARGET_FILE}"
if $HAS_YQ; then
    info "Using yq for structured YAML parsing"
else
    info "yq not found — using field-level pattern matching (install yq for more robust validation)"
fi
echo ""

# =============================================================================
# ASSERTION 1: _meta.mode is valid
# =============================================================================
info "Assertion 1: _meta.mode is valid"

if $HAS_YQ; then
    META_MODE=$(yq_read "$TARGET_FILE" '._meta.mode')
else
    META_MODE=$(fallback_field "$TARGET_FILE" "mode")
fi

if [[ "$META_MODE" == "declaration" ]] || [[ "$META_MODE" == "defaults" ]] || [[ "$META_MODE" == "inline-defaults" ]]; then
    pass "_meta.mode: '${META_MODE}' (valid)"
else
    fail "_meta.mode: '${META_MODE}' (expected one of: declaration, defaults, inline-defaults)"
fi

# Check for introspection_coverage when present (informational — not a hard requirement)
if $HAS_YQ; then
    INTROSPEC_TOOLS=$(yq_read "$TARGET_FILE" '._meta.introspection_coverage.tools')
else
    INTROSPEC_TOOLS=$(fallback_field "$TARGET_FILE" "tools")
fi
if [[ -n "$INTROSPEC_TOOLS" ]] && [[ "$INTROSPEC_TOOLS" != "null" ]]; then
    info "Introspection sub-step detected: _meta.introspection_coverage.tools = '${INTROSPEC_TOOLS}'"
fi
echo ""

# =============================================================================
# ASSERTION 2: _meta.generated_at is ISO 8601
# =============================================================================
info "Assertion 2: _meta.generated_at format"

if $HAS_YQ; then
    GENERATED_AT=$(yq_read "$TARGET_FILE" '._meta.generated_at')
else
    GENERATED_AT=$(fallback_field "$TARGET_FILE" "generated_at")
fi

if [[ "$GENERATED_AT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
    pass "_meta.generated_at: '${GENERATED_AT}' (valid ISO 8601)"
else
    fail "_meta.generated_at: '${GENERATED_AT}' (expected ISO 8601 format YYYY-MM-DDTHH:MM:SS...)"
fi
echo ""

# =============================================================================
# ASSERTION 3: _meta.defaults_version is present
# =============================================================================
info "Assertion 3: _meta.defaults_version present"

if $HAS_YQ; then
    DEFAULTS_VERSION=$(yq_read "$TARGET_FILE" '._meta.defaults_version')
else
    DEFAULTS_VERSION=$(fallback_field "$TARGET_FILE" "defaults_version")
fi

if [[ -n "$DEFAULTS_VERSION" ]] && [[ "$DEFAULTS_VERSION" != "null" ]]; then
    pass "_meta.defaults_version: '${DEFAULTS_VERSION}'"
else
    fail "_meta.defaults_version: missing or null"
fi
echo ""

# =============================================================================
# ASSERTION 4: _meta.defaults_version_date is present
# =============================================================================
info "Assertion 4: _meta.defaults_version_date present"

if $HAS_YQ; then
    DEFAULTS_VERSION_DATE=$(yq_read "$TARGET_FILE" '._meta.defaults_version_date')
else
    DEFAULTS_VERSION_DATE=$(fallback_field "$TARGET_FILE" "defaults_version_date")
fi

if [[ -n "$DEFAULTS_VERSION_DATE" ]] && [[ "$DEFAULTS_VERSION_DATE" != "null" ]]; then
    pass "_meta.defaults_version_date: '${DEFAULTS_VERSION_DATE}'"
else
    fail "_meta.defaults_version_date: missing or null"
fi
echo ""

# =============================================================================
# ASSERTION 5: _meta.schema_version is present
# =============================================================================
info "Assertion 5: _meta.schema_version present"

if $HAS_YQ; then
    SCHEMA_VERSION=$(yq_read "$TARGET_FILE" '._meta.schema_version')
else
    SCHEMA_VERSION=$(fallback_field "$TARGET_FILE" "schema_version")
fi

if [[ -n "$SCHEMA_VERSION" ]] && [[ "$SCHEMA_VERSION" != "null" ]]; then
    pass "_meta.schema_version: '${SCHEMA_VERSION}'"
else
    fail "_meta.schema_version: missing or null"
fi
echo ""

# =============================================================================
# ASSERTION 6: Tool count (>= 20, reflects expanded tool manifest with expanded tool manifest)
# =============================================================================
info "Assertion 6: Tool count"

if $HAS_YQ; then
    TOOL_COUNT=$(yq_count "$TARGET_FILE" '.platform.tools')
else
    TOOL_COUNT=$(fallback_count_array_items "$TARGET_FILE" "tools" "name")
fi

if [[ "$TOOL_COUNT" -ge 20 ]]; then
    pass "platform.tools: ${TOOL_COUNT} entries (expected >= 20)"
else
    fail "platform.tools: ${TOOL_COUNT} entries (expected >= 20)"
fi
echo ""

# =============================================================================
# ASSERTION 7: Model count (= 3)
# =============================================================================
info "Assertion 7: Model count"

if $HAS_YQ; then
    MODEL_COUNT=$(yq_count "$TARGET_FILE" '.platform.models')
else
    MODEL_COUNT=$(fallback_count_array_items "$TARGET_FILE" "models" "id")
fi

if [[ "$MODEL_COUNT" -eq 3 ]]; then
    pass "platform.models: ${MODEL_COUNT} entries (expected 3)"
else
    fail "platform.models: ${MODEL_COUNT} entries (expected 3)"
fi
echo ""

# =============================================================================
# ASSERTION 8: Each model has required fields
# =============================================================================
info "Assertion 8: Model entry required fields"

REQUIRED_MODEL_FIELDS=("id" "api_id" "tier" "context_window" "cost_ratio" "max_output_tokens")

for field in "${REQUIRED_MODEL_FIELDS[@]}"; do
    if $HAS_YQ; then
        # Check that all models have the field and it's not null
        MISSING=$(yq eval "[.platform.models[] | select(.${field} == null)] | length" "$TARGET_FILE" 2>/dev/null)
        if [[ "$MISSING" -eq 0 ]]; then
            pass "All models have '${field}'"
        else
            fail "${MISSING} model(s) missing '${field}'"
        fi
    else
        if fallback_model_has_field "$TARGET_FILE" "$field"; then
            pass "All models have '${field}'"
        else
            fail "Not all models have '${field}'"
        fi
    fi
done
echo ""

# =============================================================================
# ASSERTION 9: Hooks — SubagentStart and SessionStart
# =============================================================================
info "Assertion 9: Hook entries"

if $HAS_YQ; then
    HAS_SUBAGENT=$(yq eval '[.platform.hooks[] | select(.point == "SubagentStart")] | length' "$TARGET_FILE" 2>/dev/null)
    HAS_SESSION=$(yq eval '[.platform.hooks[] | select(.point == "SessionStart")] | length' "$TARGET_FILE" 2>/dev/null)
else
    HAS_SUBAGENT=$(sed -n '/point:.*SubagentStart/p' "$TARGET_FILE" | wc -l | tr -d ' ')
    HAS_SESSION=$(sed -n '/point:.*SessionStart/p' "$TARGET_FILE" | wc -l | tr -d ' ')
fi

if [[ "$HAS_SUBAGENT" -ge 1 ]]; then
    pass "hooks: SubagentStart entry present"
else
    fail "hooks: SubagentStart entry missing"
fi

if [[ "$HAS_SESSION" -ge 1 ]]; then
    pass "hooks: SessionStart entry present"
else
    fail "hooks: SessionStart entry missing"
fi
echo ""

# =============================================================================
# ASSERTION 10: Constraints — max_concurrent_agents fields
# =============================================================================
info "Assertion 10: Constraints fields"

if $HAS_YQ; then
    MAX_AGENTS=$(yq_read "$TARGET_FILE" '.platform.constraints.max_concurrent_agents')
    MAX_AGENTS_TYPE=$(yq_read "$TARGET_FILE" '.platform.constraints.max_concurrent_agents_type')
else
    MAX_AGENTS=$(fallback_field "$TARGET_FILE" "max_concurrent_agents")
    MAX_AGENTS_TYPE=$(fallback_field "$TARGET_FILE" "max_concurrent_agents_type")
fi

if [[ -n "$MAX_AGENTS" ]] && [[ "$MAX_AGENTS" != "null" ]]; then
    pass "constraints.max_concurrent_agents: ${MAX_AGENTS}"
else
    fail "constraints.max_concurrent_agents: missing or null"
fi

if [[ -n "$MAX_AGENTS_TYPE" ]] && [[ "$MAX_AGENTS_TYPE" != "null" ]]; then
    pass "constraints.max_concurrent_agents_type: '${MAX_AGENTS_TYPE}'"
else
    fail "constraints.max_concurrent_agents_type: missing or null"
fi
echo ""

# =============================================================================
# ASSERTION 11: Staleness check (mode-gated)
# =============================================================================
info "Assertion 11: Staleness check (defaults/inline-defaults only)"

if [[ "$META_MODE" == "defaults" ]] || [[ "$META_MODE" == "inline-defaults" ]]; then
    if [[ -n "$DEFAULTS_VERSION_DATE" ]] && [[ "$DEFAULTS_VERSION_DATE" != "null" ]] && \
       [[ "$DEFAULTS_VERSION_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        # Compute months since defaults_version_date
        # Use portable date arithmetic
        CURRENT_DATE=$(date +%Y-%m-%d)
        CURRENT_EPOCH=$(date -j -f "%Y-%m-%d" "$CURRENT_DATE" "+%s" 2>/dev/null || date -d "$CURRENT_DATE" "+%s" 2>/dev/null || echo "0")
        VERSION_EPOCH=$(date -j -f "%Y-%m-%d" "$DEFAULTS_VERSION_DATE" "+%s" 2>/dev/null || date -d "$DEFAULTS_VERSION_DATE" "+%s" 2>/dev/null || echo "0")

        if [[ "$CURRENT_EPOCH" != "0" ]] && [[ "$VERSION_EPOCH" != "0" ]]; then
            DAYS_OLD=$(( (CURRENT_EPOCH - VERSION_EPOCH) / 86400 ))
            if [[ "$DAYS_OLD" -gt 180 ]]; then
                warn "platform-defaults.yaml version ${DEFAULTS_VERSION} (dated ${DEFAULTS_VERSION_DATE}) is ${DAYS_OLD} days old (>180) — verify model roster against current Claude Code platform"
            else
                pass "Staleness: defaults_version_date '${DEFAULTS_VERSION_DATE}' is ${DAYS_OLD} days old (within 180-day threshold)"
            fi
        else
            warn "Could not compute date difference — staleness check skipped (date parsing unavailable)"
        fi
    else
        fail "Staleness check requires defaults_version_date in YYYY-MM-DD format, got: '${DEFAULTS_VERSION_DATE}'"
    fi
else
    pass "Staleness check: skipped (mode='${META_MODE}' — staleness applies only to defaults/inline-defaults)"
fi
echo ""

# =============================================================================
# ASSERTION 12: Opus context_window >= 500000 (catches reversion to 200K)
# =============================================================================
info "Assertion 12: Opus context_window"

if $HAS_YQ; then
    OPUS_CTX=$(yq eval '[.platform.models[] | select(.id == "opus")] | .[0].context_window' "$TARGET_FILE" 2>/dev/null)
else
    # Fallback: find context_window line after opus id line
    OPUS_CTX=$(awk '/id:.*opus/{found=1} found && /context_window:/{gsub(/[^0-9]/,"",$2); print $2; exit}' "$TARGET_FILE")
fi

if [[ -n "$OPUS_CTX" ]] && [[ "$OPUS_CTX" != "null" ]] && [[ "$OPUS_CTX" -ge 500000 ]]; then
    pass "Opus context_window: ${OPUS_CTX} (expected >= 500000)"
else
    fail "Opus context_window: '${OPUS_CTX}' (expected >= 500000 — may have reverted to 200K)"
fi
echo ""

# =============================================================================
# ASSERTION 13: Agent tool present in tool manifest
# =============================================================================
info "Assertion 13: Agent tool present"

if $HAS_YQ; then
    HAS_AGENT=$(yq eval '[.platform.tools[] | select(.name == "Agent")] | length' "$TARGET_FILE" 2>/dev/null)
else
    HAS_AGENT=$(sed -n '/name:.*Agent/p' "$TARGET_FILE" | wc -l | tr -d ' ')
fi

if [[ "$HAS_AGENT" -ge 1 ]]; then
    pass "platform.tools: Agent entry present"
else
    fail "platform.tools: Agent entry missing (tool may still be listed as 'Task' — update to platform name 'Agent')"
fi
echo ""

# =============================================================================
# Summary
# =============================================================================
echo "================================"
echo -e "${GREEN}PASSED${NC}: ${PASS_COUNT}"
echo -e "${RED}FAILED${NC}: ${FAIL_COUNT}"
echo -e "${YELLOW}WARNINGS${NC}: ${WARN_COUNT}"
echo "================================"

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    exit 1
else
    exit 0
fi
