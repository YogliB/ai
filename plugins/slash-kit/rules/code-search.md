---
description: Preferred code search tools - ripwire for symbols, ast-grep for structure, text search for literals and fallback
trigger: glob
globs: '**/*.{ts,tsx,js,jsx,mjs,cjs,py,pyi,go,rs,java,c,cc,cpp,h,hpp,cs,rb,swift,kt,kts,m,mm}'
alwaysApply: false
---

# Code Search and Navigation

Use the strongest tool available. Check once per session with `command -v ripwire ast-grep`; missing tools fall through to the next tier.

| Need                                                          | Tool                                                                                           |
| ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Orientation, symbol ranking, task context                     | `ripwire <dir> --for="<task>"` / `--pack-task="<task>"` via shell                              |
| Callers, callees, blast radius, usages                        | `ripwire <dir> --callers=` / `--impact=` / `--uses=` via shell                                 |
| Symbol body without reading the whole file                    | `ripwire <dir> --expand=<SYM>` via shell                                                       |
| Declarations, AST patterns, multi-site rewrites, file outline | `ast-grep --lang <lang> -p '<pattern>'` (`-r` to rewrite), `ast-grep outline <path>` via shell |
| Literal strings, comments, non-code files, fallback           | Native Grep tool; `rg` via shell when you need its flags/piping or no Grep tool exists         |

- Always pass `--legend=compact` to ripwire and `--lang` to ast-grep.
- `ripwire --pattern` accepts only structural shapes (`$A.$B()`, `fn($X)`), not bare tokens; use `--uses=` for bare symbols.
- `ripwire --pattern` covers 11 languages (C, C++, ObjC, Java, C#, JS, TS, Python, Go, Rust, Swift); for declarations or other languages, use ast-grep or text search.
- If ripwire/ast-grep are missing or return nothing useful, text search is the right call — prefer it over blind file reads.
