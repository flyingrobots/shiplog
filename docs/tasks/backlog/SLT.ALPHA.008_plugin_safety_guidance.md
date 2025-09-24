{
  "id": "SLT.ALPHA.008",
  "labels": ["docs", "security", "plugins"],
  "milestone": "Alpha",
  "name": "Expand plugin safety guidance",
  "description": "Enumerate plugin risks (malicious names, traversal, symlinks, privilege escalation) and document mitigations (canonical path checks, permissions, provenance, sandboxing, logging).",
  "priority": "P1",
  "impact": "makes threats and mitigations explicit for plugin authors",
  "steps": [
    "List common threat scenarios",
    "Define canonical path and permission checks",
    "Recommend provenance and review practices",
    "Describe execution sandboxing and audit logging"
  ],
  "blocked_by": [],
  "notes": ["strengthen docs/plugins.md safety notes (~34–38)"],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "med",
  "expected_complexity": "medium"
}

