# exempt-regions.awk — Mark each input line of a juntospec core-spec file
# with the named exemption regions it falls inside, then emit the line.
#
# Output format:  <regions-csv>\t<line-number>\t<original-line>
#                  where regions-csv is comma-separated names from the set
#                  {m16-section-3, d08-verbatim-blocks} (no spaces); empty
#                  string when the line is in no exempt region.
#
# Region definitions (mirror tier-a-assertions.sh assertions 13/15;
# do NOT modify tier-a-assertions.sh in this BL — this is a parallel
# read-only port).
#
#   m16-section-3       Active when basename(FILENAME) == "M16-derivation-architecture.md"
#                       AND we are between `## 3. Platform Capability Ingestion`
#                       (inclusive) and the next `## ` heading (exclusive).
#                       The bounding heading line itself counts as inside.
#
#   d08-verbatim-blocks Active when basename(FILENAME) == "D08-core-protocol.md"
#                       AND we are inside a fenced code block whose preceding
#                       non-empty line ended in `(verbatim):`. Fence open is
#                       any line matching ^`{3,}; close is a fence whose run
#                       length matches the opener (so a 4-tick block can
#                       contain 3-tick blocks). Defensive 30-line cap so a
#                       missing close fence does not silently exempt the rest
#                       of the file.
#
# IMPORTANT: This helper does NOT decide whether a line is exempt for a
# specific banned term — that scoping (a banned term opts in to a region by
# listing it under exempt_regions:) is the audit driver's job. This helper
# only labels each line with its region membership.
#
# Out-of-scope path (the juntogen generator tree) is enforced by the audit
# driver at file-discovery time, not by this awk pass. Post-BL-025-f the
# generator lives in a separate repo (juntogen) so the path-based scoping
# is implicit (the audit only walks files under SPEC_ROOT).
#
# Usage (from bash, single file):
#   awk -f lib/exempt-regions.awk path/to/file.md
#
# Usage (multi-file): pass each file separately. FILENAME is reset per file
# but the awk state machine is a single pass — for safety, drive one file
# per invocation in the audit script.

function basename(path,    n, parts) {
    n = split(path, parts, "/")
    return parts[n]
}

BEGIN {
    in_s3 = 0
    in_verb = 0
    verb_lines = 0
    pending_verb = 0
    open_fence = ""
}

# Reset state machine per file (defensive; audit calls one file per invocation)
FNR == 1 {
    in_s3 = 0
    in_verb = 0
    verb_lines = 0
    pending_verb = 0
    open_fence = ""
    fname = basename(FILENAME)
    is_m16 = (fname == "M16-derivation-architecture.md")
    is_d08 = (fname == "D08-core-protocol.md")
}

{
    line = $0
    regions = ""

    # --- m16-section-3 boundary tracking ---
    if (is_m16) {
        if (line ~ /^## 3\. Platform Capability Ingestion/) {
            in_s3 = 1
        } else if (in_s3 && line ~ /^## /) {
            # Next ## heading exits the region (this line is OUTSIDE)
            in_s3 = 0
        }
        if (in_s3) {
            regions = "m16-section-3"
        }
    }

    # --- d08-verbatim-blocks boundary tracking ---
    if (is_d08) {
        # Pending-verbatim: previous non-empty line ended with (verbatim):
        # The opening fence consumes this transition.
        if (line ~ /\(verbatim\):[[:space:]]*$/) {
            pending_verb = 1
            # Fall through to print (the marker line itself is NOT exempt;
            # it lives in spec prose, not in the verbatim block).
        } else if (pending_verb && line ~ /^`{3,}/) {
            # Capture fence length for exact-match close.
            match(line, /^`+/)
            open_fence = substr(line, RSTART, RLENGTH)
            in_verb = 1
            verb_lines = 0
            pending_verb = 0
            # The opening fence line is NOT exempt content; the BLOCK
            # contents start on the next line.
        } else if (pending_verb && line !~ /^`{3,}/ && line ~ /[^[:space:]]/) {
            # A non-empty line came between the marker and the fence —
            # cancel the pending state.
            pending_verb = 0
        } else if (in_verb && line ~ /^`{3,}/) {
            match(line, /^`+/)
            close_fence = substr(line, RSTART, RLENGTH)
            if (close_fence == open_fence) {
                in_verb = 0
                verb_lines = 0
                open_fence = ""
                # The closing fence line is NOT exempt.
            } else {
                # Inner fence (different length) — still inside outer block.
                verb_lines++
                if (verb_lines > 30) {
                    in_verb = 0
                    verb_lines = 0
                    open_fence = ""
                } else {
                    if (regions != "") regions = regions ","
                    regions = regions "d08-verbatim-blocks"
                }
            }
        } else if (in_verb) {
            verb_lines++
            if (verb_lines > 30) {
                # Defensive cap — runaway exemption guard.
                in_verb = 0
                verb_lines = 0
                open_fence = ""
            } else {
                if (regions != "") regions = regions ","
                regions = regions "d08-verbatim-blocks"
            }
        }
    }

    printf "%s\t%d\t%s\n", regions, FNR, line
}
