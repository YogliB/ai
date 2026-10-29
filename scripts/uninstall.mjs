#!/usr/bin/env node
/**
 * Remove the local snail Cursor plugin.
 *
 * Usage: node scripts/uninstall.mjs
 *
 * Other agents have their own removal paths:
 *   Claude Code:    claude plugin uninstall snail@snail && claude plugin marketplace remove snail
 *   Devin:          devin plugins remove snail
 *   Global skills:  npx skills remove -g
 */
import { rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { requireNode24 } from './node-guard.mjs';

requireNode24('uninstall');

const pluginHome = join(homedir(), '.cursor', 'plugins', 'local', 'snail');
rmSync(pluginHome, { recursive: true, force: true });
console.log(`Removed Cursor plugin from ${pluginHome}`);
