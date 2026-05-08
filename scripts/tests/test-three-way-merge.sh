#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MERGE_SCRIPT="$SCRIPT_DIR/../three-way-merge.sh"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

PASS=0
FAIL=0
TOTAL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    if [[ "$expected" == "$actual" ]]; then
        PASS=$((PASS + 1))
        echo "  PASS: $desc"
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL: $desc"
        echo "    expected: $expected"
        echo "    actual:   $actual"
    fi
}

run_merge() {
    local snap="$1" local_f="$2" remote="$3"
    bash "$MERGE_SCRIPT" "$snap" "$local_f" "$remote"
}

# ---------- Test 1: All fields IN_SYNC ----------
echo "Test 1: All fields IN_SYNC (snapshot == local == remote)"
cat > "$TMPDIR_TEST/snap1.json" <<'EOF'
{"stories.PROJ-1.status": "Done", "stories.PROJ-2.status": "In Progress"}
EOF
cp "$TMPDIR_TEST/snap1.json" "$TMPDIR_TEST/local1.json"
cp "$TMPDIR_TEST/snap1.json" "$TMPDIR_TEST/remote1.json"

result=$(run_merge "$TMPDIR_TEST/snap1.json" "$TMPDIR_TEST/local1.json" "$TMPDIR_TEST/remote1.json")
count=$(echo "$result" | jq '.summary.inSync')
assert_eq "all IN_SYNC count" "2" "$count"
action=$(echo "$result" | jq -r '.fields[0].action')
assert_eq "all IN_SYNC action is none" "none" "$action"
classification=$(echo "$result" | jq -r '.fields[0].classification')
assert_eq "all IN_SYNC classification" "IN_SYNC" "$classification"

# ---------- Test 2: DRIFTED_LOCAL ----------
echo "Test 2: DRIFTED_LOCAL (local changed, remote didn't)"
cat > "$TMPDIR_TEST/snap2.json" <<'EOF'
{"stories.PROJ-5.status": "To Do"}
EOF
cat > "$TMPDIR_TEST/local2.json" <<'EOF'
{"stories.PROJ-5.status": "Done"}
EOF
cp "$TMPDIR_TEST/snap2.json" "$TMPDIR_TEST/remote2.json"

result=$(run_merge "$TMPDIR_TEST/snap2.json" "$TMPDIR_TEST/local2.json" "$TMPDIR_TEST/remote2.json")
cl=$(echo "$result" | jq -r '.fields[0].classification')
assert_eq "DRIFTED_LOCAL classification" "DRIFTED_LOCAL" "$cl"
act=$(echo "$result" | jq -r '.fields[0].action')
assert_eq "DRIFTED_LOCAL action is push" "push" "$act"
assert_eq "DRIFTED_LOCAL snapshot value" "To Do" "$(echo "$result" | jq -r '.fields[0].snapshot')"
assert_eq "DRIFTED_LOCAL local value" "Done" "$(echo "$result" | jq -r '.fields[0].local')"
assert_eq "DRIFTED_LOCAL remote value" "To Do" "$(echo "$result" | jq -r '.fields[0].remote')"
assert_eq "DRIFTED_LOCAL summary" "1" "$(echo "$result" | jq '.summary.driftedLocal')"

# ---------- Test 3: DRIFTED_REMOTE ----------
echo "Test 3: DRIFTED_REMOTE (remote changed, local didn't)"
cat > "$TMPDIR_TEST/snap3.json" <<'EOF'
{"stories.PROJ-6.status": "To Do"}
EOF
cp "$TMPDIR_TEST/snap3.json" "$TMPDIR_TEST/local3.json"
cat > "$TMPDIR_TEST/remote3.json" <<'EOF'
{"stories.PROJ-6.status": "In Progress"}
EOF

result=$(run_merge "$TMPDIR_TEST/snap3.json" "$TMPDIR_TEST/local3.json" "$TMPDIR_TEST/remote3.json")
cl=$(echo "$result" | jq -r '.fields[0].classification')
assert_eq "DRIFTED_REMOTE classification" "DRIFTED_REMOTE" "$cl"
act=$(echo "$result" | jq -r '.fields[0].action')
assert_eq "DRIFTED_REMOTE action is log" "log" "$act"
assert_eq "DRIFTED_REMOTE summary" "1" "$(echo "$result" | jq '.summary.driftedRemote')"

# ---------- Test 4: CONFLICT ----------
echo "Test 4: CONFLICT (both changed differently)"
cat > "$TMPDIR_TEST/snap4.json" <<'EOF'
{"stories.PROJ-7.status": "To Do"}
EOF
cat > "$TMPDIR_TEST/local4.json" <<'EOF'
{"stories.PROJ-7.status": "Done"}
EOF
cat > "$TMPDIR_TEST/remote4.json" <<'EOF'
{"stories.PROJ-7.status": "In Progress"}
EOF

result=$(run_merge "$TMPDIR_TEST/snap4.json" "$TMPDIR_TEST/local4.json" "$TMPDIR_TEST/remote4.json")
cl=$(echo "$result" | jq -r '.fields[0].classification')
assert_eq "CONFLICT classification" "CONFLICT" "$cl"
act=$(echo "$result" | jq -r '.fields[0].action')
assert_eq "CONFLICT action is push_and_log" "push_and_log" "$act"
assert_eq "CONFLICT summary" "1" "$(echo "$result" | jq '.summary.conflict')"

# ---------- Test 5: Convergent (both changed to same value) → IN_SYNC ----------
echo "Test 5: Convergent (both changed to same value)"
cat > "$TMPDIR_TEST/snap5.json" <<'EOF'
{"stories.PROJ-8.status": "To Do"}
EOF
cat > "$TMPDIR_TEST/local5.json" <<'EOF'
{"stories.PROJ-8.status": "Done"}
EOF
cat > "$TMPDIR_TEST/remote5.json" <<'EOF'
{"stories.PROJ-8.status": "Done"}
EOF

result=$(run_merge "$TMPDIR_TEST/snap5.json" "$TMPDIR_TEST/local5.json" "$TMPDIR_TEST/remote5.json")
cl=$(echo "$result" | jq -r '.fields[0].classification')
assert_eq "Convergent classification is IN_SYNC" "IN_SYNC" "$cl"
act=$(echo "$result" | jq -r '.fields[0].action')
assert_eq "Convergent action is none" "none" "$act"

# ---------- Test 6: Mixed fields ----------
echo "Test 6: Mixed (IN_SYNC + DRIFTED_LOCAL + DRIFTED_REMOTE)"
cat > "$TMPDIR_TEST/snap6.json" <<'EOF'
{"a": "1", "b": "2", "c": "3"}
EOF
cat > "$TMPDIR_TEST/local6.json" <<'EOF'
{"a": "1", "b": "changed", "c": "3"}
EOF
cat > "$TMPDIR_TEST/remote6.json" <<'EOF'
{"a": "1", "b": "2", "c": "changed"}
EOF

result=$(run_merge "$TMPDIR_TEST/snap6.json" "$TMPDIR_TEST/local6.json" "$TMPDIR_TEST/remote6.json")
assert_eq "Mixed inSync count" "1" "$(echo "$result" | jq '.summary.inSync')"
assert_eq "Mixed driftedLocal count" "1" "$(echo "$result" | jq '.summary.driftedLocal')"
assert_eq "Mixed driftedRemote count" "1" "$(echo "$result" | jq '.summary.driftedRemote')"
assert_eq "Mixed conflict count" "0" "$(echo "$result" | jq '.summary.conflict')"
assert_eq "Mixed total fields" "3" "$(echo "$result" | jq '.fields | length')"

# ---------- Test 7: Empty snapshot (first sync) ----------
echo "Test 7: Empty snapshot (first sync) → all IN_SYNC with action none"
cat > "$TMPDIR_TEST/snap7.json" <<'EOF'
{}
EOF
cat > "$TMPDIR_TEST/local7.json" <<'EOF'
{"stories.PROJ-9.status": "Done", "epic.status": "In Progress"}
EOF
cat > "$TMPDIR_TEST/remote7.json" <<'EOF'
{"stories.PROJ-9.status": "To Do", "epic.status": "Open"}
EOF

result=$(run_merge "$TMPDIR_TEST/snap7.json" "$TMPDIR_TEST/local7.json" "$TMPDIR_TEST/remote7.json")
assert_eq "First sync all IN_SYNC" "2" "$(echo "$result" | jq '.summary.inSync')"
assert_eq "First sync no driftedLocal" "0" "$(echo "$result" | jq '.summary.driftedLocal')"
assert_eq "First sync no conflict" "0" "$(echo "$result" | jq '.summary.conflict')"
first_action=$(echo "$result" | jq -r '.fields[0].action')
assert_eq "First sync action is none" "none" "$first_action"
second_action=$(echo "$result" | jq -r '.fields[1].action')
assert_eq "First sync second action is none" "none" "$second_action"

# ---------- Test 8: New field in local only ----------
echo "Test 8: New field in local only (not in snapshot or remote)"
cat > "$TMPDIR_TEST/snap8.json" <<'EOF'
{"a": "1"}
EOF
cat > "$TMPDIR_TEST/local8.json" <<'EOF'
{"a": "1", "b": "new"}
EOF
cat > "$TMPDIR_TEST/remote8.json" <<'EOF'
{"a": "1"}
EOF

result=$(run_merge "$TMPDIR_TEST/snap8.json" "$TMPDIR_TEST/local8.json" "$TMPDIR_TEST/remote8.json")
new_field=$(echo "$result" | jq -r '.fields[] | select(.key == "b") | .classification')
assert_eq "New local field is DRIFTED_LOCAL" "DRIFTED_LOCAL" "$new_field"
new_action=$(echo "$result" | jq -r '.fields[] | select(.key == "b") | .action')
assert_eq "New local field action is push" "push" "$new_action"
new_snap=$(echo "$result" | jq -r '.fields[] | select(.key == "b") | .snapshot')
assert_eq "New local field snapshot is null" "null" "$new_snap"

# ---------- Test 9: New field in remote only ----------
echo "Test 9: New field in remote only (not in snapshot or local)"
cat > "$TMPDIR_TEST/snap9.json" <<'EOF'
{"a": "1"}
EOF
cat > "$TMPDIR_TEST/local9.json" <<'EOF'
{"a": "1"}
EOF
cat > "$TMPDIR_TEST/remote9.json" <<'EOF'
{"a": "1", "c": "remote-new"}
EOF

result=$(run_merge "$TMPDIR_TEST/snap9.json" "$TMPDIR_TEST/local9.json" "$TMPDIR_TEST/remote9.json")
new_field=$(echo "$result" | jq -r '.fields[] | select(.key == "c") | .classification')
assert_eq "New remote field is DRIFTED_REMOTE" "DRIFTED_REMOTE" "$new_field"
new_action=$(echo "$result" | jq -r '.fields[] | select(.key == "c") | .action')
assert_eq "New remote field action is log" "log" "$new_action"
new_local=$(echo "$result" | jq -r '.fields[] | select(.key == "c") | .local')
assert_eq "New remote field local is null" "null" "$new_local"

# ---------- Test 10: Summary counts are correct ----------
echo "Test 10: Summary counts are correct across all classifications"
cat > "$TMPDIR_TEST/snap10.json" <<'EOF'
{"a": "1", "b": "2", "c": "3", "d": "4", "e": "5"}
EOF
cat > "$TMPDIR_TEST/local10.json" <<'EOF'
{"a": "1", "b": "changed-b", "c": "3", "d": "changed-d", "e": "converged"}
EOF
cat > "$TMPDIR_TEST/remote10.json" <<'EOF'
{"a": "1", "b": "2", "c": "changed-c", "d": "different-d", "e": "converged"}
EOF

result=$(run_merge "$TMPDIR_TEST/snap10.json" "$TMPDIR_TEST/local10.json" "$TMPDIR_TEST/remote10.json")
assert_eq "Summary inSync (a + e convergent)" "2" "$(echo "$result" | jq '.summary.inSync')"
assert_eq "Summary driftedLocal (b)" "1" "$(echo "$result" | jq '.summary.driftedLocal')"
assert_eq "Summary driftedRemote (c)" "1" "$(echo "$result" | jq '.summary.driftedRemote')"
assert_eq "Summary conflict (d)" "1" "$(echo "$result" | jq '.summary.conflict')"
total_fields=$(echo "$result" | jq '.fields | length')
assert_eq "Total fields count" "5" "$total_fields"

# ---------- Summary ----------
echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "========================================"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
