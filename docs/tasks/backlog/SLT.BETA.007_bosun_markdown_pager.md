{
  "id": "SLT.BETA.007",
  "labels": ["bosun", "ui"],
  "milestone": "Beta",
  "name": "Bosun Markdown renderer and pager",
  "description": "Extend Bosun to render Markdown (headings, emphasis, code, tables, links) with optional paging.",
  "priority": "P1",
  "impact": "surfaces docs/runbooks directly in CLI with tables/links and a built-in pager",
  "steps": [
    "Add Markdown parse/render primitives",
    "Add display mode with ANSI styling and paging",
    "Wire `git shiplog help`/docs to use the renderer"
  ],
  "blocked_by": [],
  "notes": [],
  "created": "2025-09-25",
  "updated": "2025-09-25",
  "estimate": "med",
  "expected_complexity": "medium"
}
