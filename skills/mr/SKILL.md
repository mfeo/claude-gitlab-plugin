---
description: Fetch a GitLab merge request (metadata, description, comments or discussions, optional diff) as Markdown, optionally with a follow-up prompt. Use when the user wants to read an MR for review or fix.
argument-hint: "<project_path> <mr_iid> [--diff] [--discussions] [prompt...]"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/fetch-mr.sh*)
---

# Fetch GitLab Merge Request

Args: $ARGUMENTS

Anything after the project path, the mr iid and the optional flags is a free-form
prompt describing what to do with the merge request. It is echoed back in the
`## User Request` section below.

## Merge request context

```
!`${CLAUDE_PLUGIN_ROOT}/scripts/fetch-mr.sh $ARGUMENTS`
```

---

Read the MR above.

- If a `## User Request` section is present, treat it as the task and carry it out
  against the MR content.
- Otherwise, if the user asked for a code review fix, walk through unresolved
  discussions and propose patches.
- Otherwise, summarise the MR.
