---
name: ai-toolbelt
description: Pointer to the external AI tools used across environments. Use when the user asks about the AI toolbelt, which tools are used, or how to install a recommended tool. This skill does not install tools; it only points to them.
---

# AI Toolbelt

These are the external tools used alongside the `ai` workflow. They are not installed by this repo; point the user to the upstream URL and tell them to install the tool themselves.

## Tools

| Tool     | Use when                                                  | Trigger                              | Upstream                                                                             |
| -------- | --------------------------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------ |
| ponytail | You want the laziest/minimal solution that actually works | `/ponytail` or "use ponytail"        | https://github.com/DietrichGebert/ponytail                                           |
| caveman  | You want terse, caveman-style output                      | `/caveman <level>` or "caveman mode" | https://github.com/juliusbrussee/caveman                                             |
| grilling | You want to stress-test a plan or implementation          | `/grill ...` or "grill this"         | https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md |
| rtk      | You want to save tokens on dev operations                 | `rtk <cmd>`                          | https://github.com/rtk-ai/rtk                                                        |

## Usage

1. Load this skill when the user asks about tools, the toolbelt, or a specific recommended tool.
2. Recommend the tool that matches their request.
3. Provide the upstream URL and a one-line trigger or example.
4. Do not inline the tool's rules or instructions. Do not install it on the user's behalf.
