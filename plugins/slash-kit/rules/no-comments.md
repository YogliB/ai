---
description: No comments in source code - refactor for clarity instead
trigger: glob
globs: "**/*.{ts,tsx,js,jsx,mjs,cjs,py,pyi,go,rs,java,c,cc,cpp,h,hpp,cs,rb,swift,kt,kts,m,mm,sh,bash,zsh}"
alwaysApply: false
---

# Comments Policy

**No comments of any kind in source code.**

## Allowed

- Auto-generated headers/licenses only
- Python one-liner docstrings (`"""Single line."""`) — multi-line docstrings forbidden

## Forbidden

- Inline comments
- TODO/FIXME comments
- Explanatory, "temporary", documentation, or clarification comments

## Alternative: Refactor Instead

Comment urge = code not self-explanatory. Refactor instead:

- Rename vars/functions more descriptive
- Extract smaller functions with clear names
- Use types to express constraints/intent
- Write tests that document expected behavior
