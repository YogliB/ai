# Security Policy

## Supported Versions

This is a personal toolkit. Security updates are applied to the latest `main` branch.

## Reporting a Vulnerability

If you find a security issue in the hook, install script, or skill logic, open an issue on the repository or contact the maintainer directly.

Please include:
- A description of the issue.
- Steps to reproduce, if applicable.
- The file or command involved.

## What This Toolkit Does

- Reads user prompts (via the Claude Code `UserPromptSubmit` hook).
- Writes plan files and markdown docs to the local repository.
- Runs `gh` for PR operations through the user’s authenticated CLI.

It does not start a web server, store credentials, or make network calls itself.
