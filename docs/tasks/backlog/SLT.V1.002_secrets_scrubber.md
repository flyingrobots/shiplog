{
  "id": "SLT.V1.002",
  "labels": ["security", "plugins"],
  "milestone": "v1.0.0",
  "name": "Integrate secrets scrubber",
  "description": "Provide configurable patterns/allowlist for auto-redaction; integrate into log attachment path and add tests.",
  "priority": "P1",
  "impact": "protects journals from leaking tokens/API keys when attaching logs or structured data",
  "steps": [
    "Pattern config and allowlist",
    "Integrate into log path",
    "Add tests for redaction"
  ],
  "blocked_by": ["SLT.V1.001"],
  "notes": [],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "med",
  "expected_complexity": "medium"
}
