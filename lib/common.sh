# Common utility functions for shiplog-lite

die() {
  echo "❌ $*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

fmt_ts() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}
