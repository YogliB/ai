#!/usr/bin/env node
/**
 * Install snail as a local Cursor plugin (repo root is the plugin).
 *
 * Usage: node scripts/install.mjs
 *
 * Other agents have their own install paths:
 *   Claude Code:    claude plugin marketplace add YogliB/snail && claude plugin install snail@snail
 *   Devin:          devin plugins install YogliB/snail#plugins/snail
 *   Global skills:  npx skills add YogliB/snail -g
 */
import { cpSync, existsSync, mkdirSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { requireNode24 } from './node-guard.mjs';

requireNode24('install');

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const pluginHome = join(homedir(), '.cursor', 'plugins', 'local', 'snail');

console.log(`Installing snail Cursor plugin into ${pluginHome}`);
rmSync(pluginHome, { recursive: true, force: true });
mkdirSync(pluginHome, { recursive: true });
for (const part of ['.cursor-plugin', 'skills', 'rules']) {
	const src = join(repoRoot, part);
	if (existsSync(src)) cpSync(src, join(pluginHome, part), { recursive: true });
}
console.log("Done. Restart Cursor or run 'Developer: Reload Window' to load the plugin.");
