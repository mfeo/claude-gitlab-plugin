---
description: Fetch a GitLab merge request (metadata, description, comments or discussions, optional diff) as Markdown. Use when the user wants to read an MR for review or fix.
argument-hint: "<project_path> <mr_iid> [--diff] [--discussions]"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/fetch-mr.sh*)
---

# Fetch GitLab Merge Request

Args: $ARGUMENTS

## Merge request context

```
!`${CLAUDE_PLUGIN_ROOT}/scripts/fetch-mr.sh $ARGUMENTS`
```

---

Read the MR above. If the user asked for a code review fix, walk through unresolved discussions and propose patches; otherwise summarise the MR.
