{
  "id": "SLT.BETA.017",
  "labels": ["policy", "hooks", "cli"],
  "milestone": "Beta",
  "name": "Enforce policy fields: require_ticket/require_where/ff_only",
  "description": "Implement enforcement of documented policy fields. Validate required ticket/service/where fields in CLI (write) and server hook, and honor ff_only at policy level (complementing current per-ref FF checks).",
  "priority": "P2",
  "impact": "Brings real enforcement in line with policy documentation; increases operational safety.",
  "steps": [
    "CLI: validate required fields before composing commit",
    "Hook: enforce required fields by parsing trailer JSON",
    "Hook: enforce ff_only via policy switch (keep current FF checks as baseline)",
    "Docs: examples and guidance"
  ],
  "blocked_by": ["SLT.ALPHA.020"],
  "notes": [],
  "created": "2025-10-03",
  "updated": "2025-10-03",
  "estimate": "med",
  "expected_complexity": "medium"
}

