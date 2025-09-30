{
  "id": "SLT.BETA.014",
  "labels": ["cli", "logging"],
  "milestone": "Beta",
  "name": "Configurable run log retention strategy",
  "description": "Add size-aware handling for `git shiplog run` output and let operators pick between truncating notes or archiving full logs via Git config.",
  "priority": "P2",
  "impact": "prevents oversized git notes while giving teams control over how long run logs are kept",
  "steps": [
    "Measure captured log size before attaching notes and warn once a configurable threshold is exceeded",
    "Introduce git config to choose between truncation, compression, or alternate storage refs for large logs",
    "Document configuration knobs and recommended defaults in run/operations docs"
  ],
  "blocked_by": [],
  "notes": [
    "Default threshold should cover typical CI/stdout chatter (<1 MiB) but guard against multi-MiB dumps",
    "Consider storing oversized logs under refs/_shiplog/artifacts/<sha> as an alternative mode"
  ],
  "created": "2025-09-30",
  "updated": "2025-09-30",
  "estimate": "med",
  "expected_complexity": "medium"
}
