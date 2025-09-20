#!/usr/bin/env bats

REF_ROOT=${SHIPLOG_REF_ROOT:-refs/_shiplog}

@test "update-ref with wrong old OID fails (FF-only enforced)" {
  ref="${REF_ROOT}/journal/prod"
  tree=$(git hash-object -t tree /dev/null)
  base=$(git rev-parse --verify "$ref" 2>/dev/null || true)

  msg1="Test A"
  newA=$(echo "$msg1" | git commit-tree "$tree" ${base:+-p "$base"})
  msg2="Test B"
  newB=$(echo "$msg2" | git commit-tree "$tree" ${base:+-p "$base"})

  git update-ref -m a "$ref" "$newA" "${base:-0000000000000000000000000000000000000000}"

  run bash -lc "git update-ref -m bad '$ref' '$newB' '${base:-0000000000000000000000000000000000000000}'"
  [ "$status" -ne 0 ]
}
