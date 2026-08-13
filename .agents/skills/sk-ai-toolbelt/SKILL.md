---
name: sk-ai-toolbelt
description: Pointer to the external AI tools and MCPs used across environments. Use when the user asks about the AI toolbelt, which tools are used, or how to install a recommended tool. This skill does not install tools; it only points to them.
---

# AI Toolbelt

External skills and MCPs used alongside the `ai` workflow. They are not installed by this repo; point the user to the upstream URL and tell them to install/enable it themselves.

## Skills

| Skill         | Use when                                                      | Trigger                       | Upstream                                                                                                    |
| ------------- | ------------------------------------------------------------- | ----------------------------- | ----------------------------------------------------------------------------------------------------------- |
| ponytail      | You want the laziest/minimal solution that actually works     | `/ponytail`                   | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)                                       |
| caveman       | You want terse, caveman-style output                          | `/caveman <level>`            | [juliusbrussee/caveman](https://github.com/juliusbrussee/caveman)                                           |
| grilling      | You want to stress-test a plan or implementation              | `/grill ...`                  | [mattpocock/grilling](https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md) |
| rtk           | You want to save tokens on dev operations                     | `rtk <cmd>`                   | [rtk-ai/rtk](https://github.com/rtk-ai/rtk)                                                                 |
| documentation | You want to write clear, maintainable technical documentation | Use the `documentation` skill | [skills.sh/documentation](https://www.skills.sh/anthropics/knowledge-work-plugins/documentation)            |
| humanizer     | You want to remove signs of AI-generated writing from text    | Use the `humanizer` skill     | [skills.sh/humanizer](https://www.skills.sh/softaworks/agent-toolkit/humanizer)                             |

## MCPs

| MCP                 | Use when                                                        | Key tools                                    | Upstream                                                                                                         |
| ------------------- | --------------------------------------------------------------- | -------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| context7            | You need up-to-date library docs or code examples               | `resolve-library-id`, `get-library-docs`     | [context7.com](https://context7.com/)                                                                            |
| serena              | You need code-aware edits, search, or symbol-level refactors    | `replace_content`, `search_for_pattern`, ... | [oraios/serena](https://github.com/oraios/serena)                                                                |
| grep                | You need real-world code examples from public GitHub repos      | `searchGitHub`                               | [mcp.grep.app](https://mcp.grep.app)                                                                             |
| sequential-thinking | You need reflective, multi-step reasoning for a complex problem | `sequentialthinking`                         | [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking) |

## Usage

1. Load the sk-ai-toolbelt skill when the user asks about tools, the toolbelt, MCPs, or a specific recommended tool.
2. Recommend the tool that matches their request.
3. Provide the upstream link and a one-line trigger or example.
4. Do not inline the tool's rules, instructions, or MCP schemas. Do not install or enable it on the user's behalf.
