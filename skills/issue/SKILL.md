---
description: Fetch a GitLab issue (title, description, comments, related MRs) as Markdown. Use when the user wants to read a GitLab issue and feed it to the LLM.
argument-hint: "<project_path> <issue_iid>"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/fetch-issue.sh*)
---

# Fetch GitLab Issue

Project: $0 — Issue iid: $1

## Issue context

```
!`${CLAUDE_PLUGIN_ROOT}/scripts/fetch-issue.sh $ARGUMENTS`
```

---

Read the issue above. If the user gave a follow-up task, perform it; otherwise summarise the issue and propose next actions.
