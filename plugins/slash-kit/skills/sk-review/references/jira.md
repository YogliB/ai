# Jira

Extract: issue keys (`[A-Z][A-Z0-9]+-[0-9]+`, e.g. `ABC-123`) and Jira browse URLs.

Resolve: use the connected Jira tools when the environment has them — fetch the summary, description, status, and parent/epic link. Without Jira tools, web-fetch the ticket URL when one was given; tickets are usually behind auth. A bare key has no URL — never construct one; without connected Jira tools it is `not opened (no tool)`.

Follow: the epic or parent link and linked issues, one level at a time — this is the usual path from ticket to epic to spec.

Read-only: never transition, assign, label, or comment.
