---
description: Fetch a GitLab issue (title, description, comments, related MRs) as Markdown, optionally with a follow-up prompt. Use when the user wants to read a GitLab issue and feed it to the LLM.
argument-hint: "<project_path> <issue_iid> [prompt...]"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/fetch-issue.sh*)
---

# Fetch GitLab Issue

Args: $ARGUMENTS

Anything after the project path and the issue iid is a free-form prompt describing
what to do with the issue. It is echoed back in the `## User Request` section below.

## Issue context

```
!`${CLAUDE_PLUGIN_ROOT}/scripts/fetch-issue.sh $ARGUMENTS`
```

---

Read the issue above.

- If a `## User Request` section is present, treat it as the task and carry it out
  against the issue content.
- Otherwise, summarise the issue and propose next actions.
