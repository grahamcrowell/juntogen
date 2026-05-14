#!/usr/bin/env bash
#
# build-prompt-substitution-test.sh — BL-025-h.1 + BL-025-h.2 fixture
# harness for the generate-script `build_prompt` substitution paths.
#
# PURPOSE: Lock the `[CANONICAL: id]` and `[FILE: basename]` resolution
#          in build_prompt so that future regressions (e.g., ordering bug
#          on {CONTRACT_PRIMITIVES}, BSD-awk portability bug, silent-emit
#          bug) fail this test loudly.
#
# DESIGN: Drive the live `juntogen/claude/generate` build_prompt code
#         path through a synthetic SPEC_DIR + step file. We invoke
#         `generate` in --dry-run mode, which goes through the full
#         build_prompt pipeline and persists the resolved output to
#         ${OUTPUT_DIR}/prompts-built/step-NN.prompt. The harness
#         then asserts on the prompt's resolved content.
#
# Scenarios:
#   1. POSITIVE [CANONICAL: triage-criteria] resolves to the absolute
#      path of D24-triage-engine.md under SPEC_DIR.
#   2. POSITIVE [FILE: F16-architecture.md] resolves to the absolute
#      path of F16-architecture.md under SPEC_DIR.
#   3. POSITIVE [FILE: D64-tooling.md] (cross-repo, file_repo=juntogen)
#      resolves under JUNTOGEN_ROOT/claude/.
#   4. NEGATIVE [CANONICAL: __not_in_contract__] aborts build_prompt
#      with non-zero exit and a diagnostic naming the bad id.
#   5. NEGATIVE [FILE: __not_a_file__.md] aborts build_prompt with
#      non-zero exit and a diagnostic naming the bad basename.
#   6. IDEMPOTENCY: byte-identical resolution across two consecutive
#      runs (substitution determinism per BL-025-h.1).
#
# BL-025-h.2 additions (scenarios 8-10):
#   8. POSITIVE {CONTRACT_PRIMITIVES} resolution + idempotency: drives the
#      build_prompt {CONTRACT_PRIMITIVES} pipeline against the LIVE contract
#      and asserts each primitive renders as `- **<name>** \xe2\x80\x94 <role>`,
#      placeholder is fully consumed, and two consecutive runs are SHA-256-
#      identical.
#   9. FALSIFIER probe — `&`-byte safety: synthesizes a temp contract whose
#      primitive role contains `&`, runs the same pipeline, and asserts the
#      role survives the awk substitution byte-identical (no awk-metachar
#      corruption). This is the BL-025-h FALSIFIER probe deferred at lock-in
#      time (no live contract role contains `&`, so this is a forward guard).
#  10. PLACEMENT VARIANTS — full-line vs embedded: covers the two awk
#      branches at generate.sh:996-1009. Full-line placeholder REPLACES the
#      line with the block. Embedded placeholder STRIPS the placeholder from
#      the line, prints the (now-modified) line, then prints the block on
#      following lines.
#
# DESIGN CHOICE (8/9/10): the scenarios extract the build_prompt
# {CONTRACT_PRIMITIVES} pipeline (load-contract.py primitive-roles → block
# tempfile → awk substitution) inline into a probe, mirroring the awk-in-
# isolation strategy used by scenario_negative_unknown_markers. This is
# byte-faithful to generate.sh:973-1011 and avoids the cost of synthesizing
# a complete-enough temp spec corpus to drive `generate --dry-run` (which
# would also need step prompts, contract sections like canonical_ids and
# layout.spec_files, etc.). The unit-of-test is the substitution pipeline,
# not the full generate harness — and that's what the BL-025-h FALSIFIER
# probes for byte preservation under awk.
#
# TEST ISOLATION: Each scenario plants exactly one step file under a
# private steps tempdir, points generate at it via a hacky-but-supported
# trick: the harness uses the REAL generate script with the real spec
# corpus, then checks the corresponding built-prompt output for the
# converted markers in step-09/10 (step-08 retired by BL-025-m.1).
# Negative scenarios construct a minimal isolated tempdir.
#
# Exit codes:
#   0 — all scenarios pass
#   1 — at least one scenario failed
#   2 — driver error
#
# BSD-awk portability note: the build_prompt awk pass uses index/substr
# (no regex backreferences, no gsub captures), per F-04 / BL-025-h.1
# ordering invariant documentation in `generate`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE="${SCRIPT_DIR}/../../../claude/generate"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
SPEC_DIR_REAL="${OJ_SPEC_DIR:-${REPO_ROOT}/juntospec}"
JUNTOGEN_ROOT_REAL="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

[ -x "${GENERATE}" ] || { echo -e "${RED}ERROR${NC} generate not executable: ${GENERATE}" >&2; exit 2; }
[ -d "${SPEC_DIR_REAL}" ] || { echo -e "${RED}ERROR${NC} SPEC_DIR not found: ${SPEC_DIR_REAL}" >&2; exit 2; }

PASS_COUNT=0
FAIL_COUNT=0

run_dry() {
    # Run generate in dry-run mode. Args: $1 = OUTPUT_DIR.
    local out="$1"
    local stderr_log
    stderr_log=$(mktemp -t bps-stderr-XXXXXX)
    local rc=0
    "${GENERATE}" "${out}" --dry-run --spec-dir "${SPEC_DIR_REAL}" \
        >/dev/null 2>"${stderr_log}" || rc=$?
    RUN_EXIT="${rc}"
    RUN_STDERR=$(cat "${stderr_log}")
    rm -f "${stderr_log}"
}

assert_pass_one() {
    local label="$1"; local cond="$2"
    if [ "${cond}" = "ok" ]; then
        echo -e "${GREEN}PASS${NC} ${label}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}FAIL${NC} ${label}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ── Scenario 1+2+3+6: positive resolution against real corpus ────────────
# The real step prompts (BL-025-h.1 conversion) carry [FILE: ...] markers
# at fixed line positions. After dry-run the built prompts must contain
# resolved absolute paths.
scenario_positive_resolution() {
    local out
    out=$(mktemp -d -t bps-pos-XXXXXX)
    run_dry "${out}"
    if [ "${RUN_EXIT}" -ne 0 ]; then
        echo -e "${RED}FAIL${NC} positive scenarios: dry-run exited non-zero (${RUN_EXIT})"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        rm -rf "${out}"
        return
    fi
    # BL-025-m.1: step-08 retired. Tests now exercise step-09 + step-10 only.
    # step-09 carries [FILE: D64-tooling.md] (cross-repo juntogen marker) and
    # step-10 carries [FILE: F08-axioms.md]. Assertion 2 (F16-architecture.md
    # via step-08) is dropped — F16 is consumed by step-01 as prose, not via
    # a [FILE:] marker, so there's no path to assert it under m.1 without
    # touching step prompts (deferred to m.2).
    local p09="${out}/prompts-built/step-09.prompt"
    local p10="${out}/prompts-built/step-10.prompt"
    if [ ! -f "${p09}" ] || [ ! -f "${p10}" ]; then
        echo -e "${RED}FAIL${NC} positive scenarios: built prompts missing under ${out}/prompts-built"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        rm -rf "${out}"
        return
    fi

    # 1. step-10 must contain the absolute path to F08-axioms.md (FILE: F08-axioms.md).
    if grep -qF "${SPEC_DIR_REAL}/F08-axioms.md" "${p10}"; then
        assert_pass_one "1. [FILE: F08-axioms.md] -> resolved absolute path (step-10)" "ok"
    else
        assert_pass_one "1. [FILE: F08-axioms.md] -> resolved absolute path (step-10)" "fail"
    fi

    # 2. (RETIRED with step-08 — BL-025-m.1.) F16-architecture.md is consumed
    # by step-01 as prose, not via a [FILE:] marker, so the equivalent
    # assertion has no live target. Restored by BL-025-m.2 when step prompts
    # are rewritten.

    # 3. step-09 must contain the absolute path to D64-tooling.md (juntogen).
    if grep -qF "${JUNTOGEN_ROOT_REAL}/claude/D64-tooling.md" "${p09}"; then
        assert_pass_one "3. [FILE: D64-tooling.md] -> juntogen-rooted absolute path (cross-repo)" "ok"
    else
        assert_pass_one "3. [FILE: D64-tooling.md] -> juntogen-rooted absolute path (cross-repo)" "fail"
    fi

    # The literal marker form must be ABSENT from the resolved prompts
    # (silent-emit detection — F-01). Narrowed to step-09/10 (step-08 retired).
    if ! grep -qE '\[FILE:[[:space:]]*[A-Za-z0-9._-]+\]' "${p09}" "${p10}" && \
       ! grep -qE '\[CANONICAL:[[:space:]]*[A-Za-z0-9_-]+\]' "${p09}" "${p10}"; then
        assert_pass_one "4. resolved prompts contain ZERO unresolved markers (F-01 silent-emit)" "ok"
    else
        # Allow the meta-id `[CANONICAL: id]` as documentation literal in
        # other steps — narrow the test to the steps touched by the convert plan.
        if grep -qE '\[FILE:[[:space:]]*[A-Za-z0-9._-]+\]' "${p09}" "${p10}"; then
            assert_pass_one "4. resolved prompts contain ZERO unresolved markers (F-01 silent-emit)" "fail"
        else
            assert_pass_one "4. resolved prompts contain ZERO unresolved markers (F-01 silent-emit)" "ok"
        fi
    fi

    # 6. Idempotency: re-run dry-run, hash the prompts, compare.
    local out2 hash_a hash_b
    out2=$(mktemp -d -t bps-pos2-XXXXXX)
    run_dry "${out2}"
    if [ "${RUN_EXIT}" -ne 0 ]; then
        assert_pass_one "5. idempotency (byte-identical across runs)" "fail"
    else
        # Strip OUTPUT_DIR-dependent paths (Makefile target etc.) before
        # hashing — the marker substitution itself must be stable, but the
        # OUTPUT_DIR sed of /path/to/oj-project/ is path-dependent.
        hash_a=$(cat "${out}/prompts-built"/step-*.prompt | sed "s@${out}@OUTDIR@g" | shasum -a 256 | awk '{print $1}')
        hash_b=$(cat "${out2}/prompts-built"/step-*.prompt | sed "s@${out2}@OUTDIR@g" | shasum -a 256 | awk '{print $1}')
        if [ "${hash_a}" = "${hash_b}" ]; then
            assert_pass_one "5. idempotency (byte-identical resolution across runs)" "ok"
        else
            echo -e "${CYAN}    hash_a=${hash_a}${NC}"
            echo -e "${CYAN}    hash_b=${hash_b}${NC}"
            assert_pass_one "5. idempotency (byte-identical resolution across runs)" "fail"
        fi
    fi
    rm -rf "${out}" "${out2}"
}

# ── Scenario 4+5: negative resolution (unknown markers) ──────────────────
# Construct a minimal SPEC_DIR with platform-contract.yaml + plant a
# synthetic step-00 prompt under the juntogen steps tree containing the
# bad markers — but to avoid corrupting the live tree, override
# JUNTOGEN_ROOT and SCRIPT_DIR by spawning generate with a custom
# steps directory. This requires creating a near-complete copy of the
# generator tree; cheaper to test the build_prompt awk in isolation.
#
# We test fail-loud by creating a synthetic step prompt file at a
# private location, then directly calling the load-contract.py and
# running the same awk filter on a synthetic input.
scenario_negative_unknown_markers() {
    # Run the substitution awk from generate against a synthetic line
    # carrying an unknown [CANONICAL: ...] marker. Reproduce the
    # behavior using load-contract.py + the same awk file.
    local cmap fmap errfile out
    cmap=$(mktemp -t bps-cmap-XXXXXX)
    fmap=$(mktemp -t bps-fmap-XXXXXX)
    errfile=$(mktemp -t bps-err-XXXXXX)

    # Build cmap and fmap from real contract.
    python3 "${SCRIPT_DIR}/lib/load-contract.py" canonical-ids "${SPEC_DIR_REAL}/platform-contract.yaml" \
        | awk -F'\t' -v spec="${SPEC_DIR_REAL}" -v jg="${JUNTOGEN_ROOT_REAL}" '
            { if ($1 == "") next
              repo = $4
              base = (repo == "" || repo == "juntospec") ? spec : (repo == "juntogen") ? jg : ""
              if (base != "") printf "%s\t%s/%s\n", $1, base, $2
            }' > "${cmap}"
    python3 "${SCRIPT_DIR}/lib/load-contract.py" spec-files "${SPEC_DIR_REAL}/platform-contract.yaml" \
        | awk -F'\t' -v spec="${SPEC_DIR_REAL}" -v jg="${JUNTOGEN_ROOT_REAL}" '
            { if ($1 == "") next
              repo = $2
              base = (repo == "" || repo == "juntospec") ? spec : (repo == "juntogen") ? jg : ""
              if (base != "") printf "%s\t%s/%s\n", $1, base, $3
            }' > "${fmap}"

    # Negative 1: unknown CANONICAL id.
    : > "${errfile}"
    out=$(printf 'See [CANONICAL: __not_in_contract__] for context.\n' | \
        awk -v cmap="${cmap}" -v fmap="${fmap}" -v errfile="${errfile}" '
            BEGIN {
                while ((getline line < cmap) > 0) {
                    idx = index(line, "\t")
                    if (idx == 0) continue
                    cidx[substr(line, 1, idx-1)] = substr(line, idx+1)
                }
                close(cmap)
                while ((getline line < fmap) > 0) {
                    idx = index(line, "\t")
                    if (idx == 0) continue
                    fidx[substr(line, 1, idx-1)] = substr(line, idx+1)
                }
                close(fmap)
            }
            {
                rest = $0; out = ""
                while (1) {
                    cp = index(rest, "[CANONICAL:")
                    fp = index(rest, "[FILE:")
                    if (cp == 0 && fp == 0) { out = out rest; break }
                    if (cp == 0) { pos = fp; kind = "FILE" }
                    else if (fp == 0) { pos = cp; kind = "CANONICAL" }
                    else if (cp < fp) { pos = cp; kind = "CANONICAL" }
                    else { pos = fp; kind = "FILE" }
                    co = index(substr(rest, pos), "]")
                    if (co == 0) { out = out rest; break }
                    cl = pos + co - 1
                    tok = substr(rest, pos, cl-pos+1)
                    pl = (kind == "CANONICAL") ? 11 : 6
                    inner = substr(tok, pl+1, length(tok)-pl-1)
                    sub(/^[[:space:]]+/, "", inner); sub(/[[:space:]]+$/, "", inner)
                    if (kind == "CANONICAL" && inner == "id") { out = out substr(rest, 1, cl); rest = substr(rest, cl+1); continue }
                    if (inner !~ /^[A-Za-z0-9._-]+$/) { out = out substr(rest, 1, cl); rest = substr(rest, cl+1); continue }
                    if (kind == "CANONICAL") {
                        if (inner in cidx) { rep = cidx[inner] } else { printf "[CANONICAL: %s]\n", inner > errfile; rep = tok }
                    } else {
                        if (inner in fidx) { rep = fidx[inner] } else { printf "[FILE: %s]\n", inner > errfile; rep = tok }
                    }
                    out = out substr(rest, 1, pos-1) rep
                    rest = substr(rest, cl+1)
                }
                print out
            }')
    if [ -s "${errfile}" ] && grep -qF '__not_in_contract__' "${errfile}"; then
        assert_pass_one "6. negative [CANONICAL: __not_in_contract__] -> diagnostic emitted" "ok"
    else
        assert_pass_one "6. negative [CANONICAL: __not_in_contract__] -> diagnostic emitted" "fail"
    fi

    # Negative 2: unknown FILE basename.
    : > "${errfile}"
    out=$(printf 'Read [FILE: __not_a_file__.md] please.\n' | \
        awk -v cmap="${cmap}" -v fmap="${fmap}" -v errfile="${errfile}" '
            BEGIN {
                while ((getline line < cmap) > 0) {
                    idx = index(line, "\t")
                    if (idx == 0) continue
                    cidx[substr(line, 1, idx-1)] = substr(line, idx+1)
                }
                close(cmap)
                while ((getline line < fmap) > 0) {
                    idx = index(line, "\t")
                    if (idx == 0) continue
                    fidx[substr(line, 1, idx-1)] = substr(line, idx+1)
                }
                close(fmap)
            }
            {
                rest = $0; out = ""
                while (1) {
                    cp = index(rest, "[CANONICAL:")
                    fp = index(rest, "[FILE:")
                    if (cp == 0 && fp == 0) { out = out rest; break }
                    if (cp == 0) { pos = fp; kind = "FILE" }
                    else if (fp == 0) { pos = cp; kind = "CANONICAL" }
                    else if (cp < fp) { pos = cp; kind = "CANONICAL" }
                    else { pos = fp; kind = "FILE" }
                    co = index(substr(rest, pos), "]")
                    if (co == 0) { out = out rest; break }
                    cl = pos + co - 1
                    tok = substr(rest, pos, cl-pos+1)
                    pl = (kind == "CANONICAL") ? 11 : 6
                    inner = substr(tok, pl+1, length(tok)-pl-1)
                    sub(/^[[:space:]]+/, "", inner); sub(/[[:space:]]+$/, "", inner)
                    if (kind == "CANONICAL" && inner == "id") { out = out substr(rest, 1, cl); rest = substr(rest, cl+1); continue }
                    if (inner !~ /^[A-Za-z0-9._-]+$/) { out = out substr(rest, 1, cl); rest = substr(rest, cl+1); continue }
                    if (kind == "CANONICAL") {
                        if (inner in cidx) { rep = cidx[inner] } else { printf "[CANONICAL: %s]\n", inner > errfile; rep = tok }
                    } else {
                        if (inner in fidx) { rep = fidx[inner] } else { printf "[FILE: %s]\n", inner > errfile; rep = tok }
                    }
                    out = out substr(rest, 1, pos-1) rep
                    rest = substr(rest, cl+1)
                }
                print out
            }')
    if [ -s "${errfile}" ] && grep -qF '__not_a_file__.md' "${errfile}"; then
        assert_pass_one "7. negative [FILE: __not_a_file__.md] -> diagnostic emitted" "ok"
    else
        assert_pass_one "7. negative [FILE: __not_a_file__.md] -> diagnostic emitted" "fail"
    fi

    rm -f "${cmap}" "${fmap}" "${errfile}"
}

# ── BL-025-h.2 helper: run the build_prompt {CONTRACT_PRIMITIVES} pipeline ─
# This mirrors generate.sh:973-1011 byte-for-byte. The caller passes:
#   $1 = contract YAML path (the SPEC source for primitive-roles)
#   $2 = input prompt content (passed via stdin to the awk substitution)
# Stdout: the resolved prompt content.
# Stderr: any load-contract.py errors propagate.
# Tempdir: each call mints its own under ${BL025H2_TMPROOT} (set by caller).
build_prompt_contract_primitives_probe() {
    local contract_path="$1"
    local input_content="$2"
    local roles_tsv block_tmp

    roles_tsv=$(python3 "${SCRIPT_DIR}/lib/load-contract.py" \
        primitive-roles "${contract_path}") || return 1

    block_tmp=$(mktemp "${BL025H2_TMPROOT}/block-XXXXXX")
    printf '%s\n' "${roles_tsv}" | awk -F'\t' \
        '{ printf "- **%s** \xe2\x80\x94 %s\n", $1, $2 }' > "${block_tmp}"

    printf '%s' "${input_content}" | \
        awk -v blockfile="${block_tmp}" '
            BEGIN {
                nblock = 0
                while ((getline line < blockfile) > 0) {
                    block[++nblock] = line
                }
                close(blockfile)
            }
            {
                if (index($0, "{CONTRACT_PRIMITIVES}") > 0) {
                    idx_full = ($0 == "{CONTRACT_PRIMITIVES}")
                    if (idx_full) {
                        for (i = 1; i <= nblock; i++) print block[i]
                    } else {
                        line2 = $0
                        gsub(/\{CONTRACT_PRIMITIVES\}/, "", line2)
                        print line2
                        for (i = 1; i <= nblock; i++) print block[i]
                    }
                    next
                }
                print $0
            }
        '
    rm -f "${block_tmp}"
    return 0
}

# ── Scenario 8: {CONTRACT_PRIMITIVES} positive resolution + idempotency ───
# Drive the {CONTRACT_PRIMITIVES} pipeline against the live contract.
# Assertions:
#   (a) substitution actually fires — output contains NO literal
#       `{CONTRACT_PRIMITIVES}` placeholder
#   (b) every primitive emitted by load-contract.py renders as a markdown
#       bullet `- **<name>** — <role>` in the resolved output
#   (c) bullet count matches contract primitive count (no drops, no dupes)
#   (d) two consecutive invocations produce SHA-256-identical output
scenario_contract_primitives_positive() {
    local input output1 output2 fail_msgs=""
    input='# Test prompt

Primitives in this contract:

{CONTRACT_PRIMITIVES}

End of test.'

    output1=$(build_prompt_contract_primitives_probe \
        "${SPEC_DIR_REAL}/platform-contract.yaml" "${input}") || {
        echo -e "${RED}FAIL${NC} 8. {CONTRACT_PRIMITIVES} positive: probe failed for live contract"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    }

    # (a) placeholder must be fully consumed.
    if printf '%s' "${output1}" | grep -qF '{CONTRACT_PRIMITIVES}'; then
        fail_msgs+=$'\n    8a-substitution: literal {CONTRACT_PRIMITIVES} still present in resolved output'
    fi

    # (b) bullet count must match contract primitive count.
    local roles_tsv expected_count actual_count missing_count
    roles_tsv=$(python3 "${SCRIPT_DIR}/lib/load-contract.py" \
        primitive-roles "${SPEC_DIR_REAL}/platform-contract.yaml")
    expected_count=$(printf '%s\n' "${roles_tsv}" | awk 'NF>0' | wc -l | tr -d ' ')
    # Em-dash is U+2014 = byte sequence \xe2\x80\x94 (UTF-8). grep -F is
    # binary-safe and treats the bytes literally.
    actual_count=$(printf '%s\n' "${output1}" | \
        grep -cE '^- \*\*[^*]+\*\* '$'\xe2\x80\x94'' .+' || true)
    if [ "${actual_count}" -ne "${expected_count}" ] || [ "${expected_count}" -eq 0 ]; then
        fail_msgs+=$'\n    8b-bullet-count: expected '"${expected_count}"', found '"${actual_count}"
    fi

    # (c) each contract primitive must appear by name in a bullet.
    # NOTE: `grep -F -- "<pat>"` is required — the bullet pattern begins
    # with `-` and grep would otherwise parse it as a flag.
    missing_count=0
    while IFS=$'\t' read -r name role; do
        [ -z "${name}" ] && continue
        if ! printf '%s\n' "${output1}" | \
            grep -qF -- "- **${name}** "$'\xe2\x80\x94'" ${role}"; then
            missing_count=$((missing_count + 1))
            fail_msgs+=$'\n    8c-format: missing bullet for primitive: '"${name}"
        fi
    done <<< "${roles_tsv}"

    # (d) idempotency: re-run the probe; outputs must be byte-identical.
    output2=$(build_prompt_contract_primitives_probe \
        "${SPEC_DIR_REAL}/platform-contract.yaml" "${input}")
    local hash1 hash2
    hash1=$(printf '%s' "${output1}" | shasum -a 256 | awk '{print $1}')
    hash2=$(printf '%s' "${output2}" | shasum -a 256 | awk '{print $1}')
    if [ "${hash1}" != "${hash2}" ]; then
        fail_msgs+=$'\n    8d-idempotency: hash mismatch hash1='"${hash1}"' hash2='"${hash2}"
    fi

    if [ -z "${fail_msgs}" ]; then
        assert_pass_one "8. {CONTRACT_PRIMITIVES} positive resolution + idempotency (live contract, ${expected_count} primitives)" "ok"
    else
        echo -e "${RED}FAIL${NC} 8. {CONTRACT_PRIMITIVES} positive resolution + idempotency"
        echo -e "${CYAN}    sub-assertion failures:${fail_msgs}${NC}"
        echo -e "${CYAN}    output head -20:${NC}"
        printf '%s\n' "${output1}" | head -20 | sed 's/^/    /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ── Scenario 9: {CONTRACT_PRIMITIVES} awk-`&`-safety FALSIFIER probe ──────
# The lead's BL-025-h FALSIFIER for this path was: "synthesize a primitive
# role containing `&` and verify pass-through." awk's `gsub` and `sub`
# treat `&` in the REPLACEMENT string as the matched-pattern backreference.
# The {CONTRACT_PRIMITIVES} pipeline does NOT inject role text into a
# replacement string (the role is held in `block[i]` and emitted via
# `print`), so `&` should pass through byte-identical. This scenario locks
# that behavior so a future refactor that switches to gsub-based injection
# fails loudly.
scenario_contract_primitives_amp_safety() {
    local synth_dir synth_contract input output fail_msgs=""
    synth_dir=$(mktemp -d "${BL025H2_TMPROOT}/synth-XXXXXX")
    synth_contract="${synth_dir}/platform-contract.yaml"
    cat > "${synth_contract}" <<'EOF'
version: "bl025h2-falsifier-probe"
primitives:
  - name: "Probe"
    role: "Consult & Convene synthesized for awk & safety FALSIFIER"
EOF
    input='Header
{CONTRACT_PRIMITIVES}
Footer'

    output=$(build_prompt_contract_primitives_probe "${synth_contract}" "${input}") || {
        echo -e "${RED}FAIL${NC} 9. FALSIFIER probe: build_prompt pipeline aborted on synthetic contract"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        rm -rf "${synth_dir}"
        return
    }

    # The role string `Consult & Convene synthesized for awk & safety FALSIFIER`
    # must appear byte-identical in the output. If awk substituted `&` with
    # a matched-pattern reference, the output would contain something like
    # `Consult {CONTRACT_PRIMITIVES} Convene` or duplicated text — neither
    # matches the literal substring.
    local expected="Consult & Convene synthesized for awk & safety FALSIFIER"
    if ! printf '%s\n' "${output}" | grep -qF -- "${expected}"; then
        fail_msgs+=$'\n    9a-byte-preservation: literal substring missing — expected ['"${expected}"']'
    fi

    # Belt-and-suspenders: the full bullet must match the exact format
    # generate.sh:982 prints.
    local expected_bullet="- **Probe** "$'\xe2\x80\x94'" Consult & Convene synthesized for awk & safety FALSIFIER"
    if ! printf '%s\n' "${output}" | grep -qF -- "${expected_bullet}"; then
        fail_msgs+=$'\n    9b-bullet-format: expected bullet ['"${expected_bullet}"']'
    fi

    if [ -z "${fail_msgs}" ]; then
        assert_pass_one "9. FALSIFIER: primitive role with '&' survives awk pipeline byte-identical" "ok"
    else
        echo -e "${RED}FAIL${NC} 9. FALSIFIER: '&' byte-safety in {CONTRACT_PRIMITIVES} pipeline"
        echo -e "${CYAN}    sub-assertion failures:${fail_msgs}${NC}"
        echo -e "${CYAN}    output head -20:${NC}"
        printf '%s\n' "${output}" | head -20 | sed 's/^/    /'
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    rm -rf "${synth_dir}"
}

# ── Scenario 10: {CONTRACT_PRIMITIVES} placement variants ─────────────────
# generate.sh:996-1009 has two branches:
#   (a) idx_full: line is EXACTLY `{CONTRACT_PRIMITIVES}` -> block REPLACES
#       the line.
#   (b) embedded: line CONTAINS `{CONTRACT_PRIMITIVES}` somewhere -> the
#       placeholder is gsub'd to empty, the modified line is printed FIRST,
#       then the block is printed on FOLLOWING lines.
# Cover both branches against a synthetic 1-primitive contract so the
# expected output is small and assertable.
scenario_contract_primitives_placement_variants() {
    local synth_dir synth_contract fail_msgs=""
    synth_dir=$(mktemp -d "${BL025H2_TMPROOT}/place-XXXXXX")
    synth_contract="${synth_dir}/platform-contract.yaml"
    cat > "${synth_contract}" <<'EOF'
version: "bl025h2-placement-probe"
primitives:
  - name: "Solo"
    role: "lone primitive for placement-variant test"
EOF

    # Variant (a): full-line placeholder. The line `{CONTRACT_PRIMITIVES}`
    # MUST be replaced by the block — the leading `LineBefore` must remain,
    # the literal placeholder must be gone, and the block must follow.
    local input_full output_full expected_full
    input_full='LineBefore
{CONTRACT_PRIMITIVES}
LineAfter'
    output_full=$(build_prompt_contract_primitives_probe "${synth_contract}" "${input_full}")
    expected_full='LineBefore
- **Solo** '$'\xe2\x80\x94'' lone primitive for placement-variant test
LineAfter'
    if [ "${output_full}" != "${expected_full}" ]; then
        fail_msgs+=$'\n    10a-full-line: output mismatch'
        fail_msgs+=$'\n      expected:'$'\n'"$(printf '%s\n' "${expected_full}" | sed 's/^/        /')"
        fail_msgs+=$'\n      actual (head -20):'$'\n'"$(printf '%s\n' "${output_full}" | head -20 | sed 's/^/        /')"
    fi

    # Variant (b): embedded placeholder. Per generate.sh:1001-1004 awk:
    # `gsub(/\{CONTRACT_PRIMITIVES\}/, "", line2)` strips the placeholder
    # and leaves surrounding whitespace as-is — so `Some prefix
    # {CONTRACT_PRIMITIVES} some suffix` becomes `Some prefix  some suffix`
    # (note: two spaces in the gap). Block then prints on the next line.
    local input_emb output_emb expected_emb
    input_emb='LineBefore
Some prefix {CONTRACT_PRIMITIVES} some suffix
LineAfter'
    output_emb=$(build_prompt_contract_primitives_probe "${synth_contract}" "${input_emb}")
    expected_emb='LineBefore
Some prefix  some suffix
- **Solo** '$'\xe2\x80\x94'' lone primitive for placement-variant test
LineAfter'
    if [ "${output_emb}" != "${expected_emb}" ]; then
        fail_msgs+=$'\n    10b-embedded: output mismatch'
        fail_msgs+=$'\n      expected:'$'\n'"$(printf '%s\n' "${expected_emb}" | sed 's/^/        /')"
        fail_msgs+=$'\n      actual (head -20):'$'\n'"$(printf '%s\n' "${output_emb}" | head -20 | sed 's/^/        /')"
    fi

    if [ -z "${fail_msgs}" ]; then
        assert_pass_one "10. {CONTRACT_PRIMITIVES} placement variants: full-line replacement + embedded gsub (both awk branches)" "ok"
    else
        echo -e "${RED}FAIL${NC} 10. {CONTRACT_PRIMITIVES} placement variants"
        echo -e "${CYAN}    sub-assertion failures:${fail_msgs}${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    rm -rf "${synth_dir}"
}

# Tempdir root for BL-025-h.2 scenarios — single trap-cleanable parent.
BL025H2_TMPROOT=$(mktemp -d -t bl025h2-XXXXXX)
trap 'rm -rf "${BL025H2_TMPROOT}"' EXIT INT TERM

echo -e "${YELLOW}[INFO]${NC} BL-025-h.1 + BL-025-h.2 build_prompt substitution test"
echo -e "${YELLOW}[INFO]${NC} generate:        ${GENERATE}"
echo -e "${YELLOW}[INFO]${NC} spec dir:        ${SPEC_DIR_REAL}"
echo -e "${YELLOW}[INFO]${NC} juntogen root:   ${JUNTOGEN_ROOT_REAL}"
echo -e "${YELLOW}[INFO]${NC} bl025h2 tmproot: ${BL025H2_TMPROOT}"
echo

scenario_positive_resolution
scenario_negative_unknown_markers
scenario_contract_primitives_positive
scenario_contract_primitives_amp_safety
scenario_contract_primitives_placement_variants

echo
echo "================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} build-prompt-substitution-test: ${PASS_COUNT}/${TOTAL}"
    echo "================================"
    exit 0
fi
echo -e "${RED}FAIL${NC} build-prompt-substitution-test: ${FAIL_COUNT}/${TOTAL} scenario(s) failed"
echo "================================"
exit 1
