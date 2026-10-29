#!/usr/bin/env node
/**
 * Install the snail rules for Claude Code: copy rules/*.md without their
 * YAML frontmatter into ~/.claude/snail/ and link each from ~/.claude/CLAUDE.md.
 *
 * Usage: node scripts/install-claude-rules.mjs
 */
import {
	appendFileSync,
	mkdirSync,
	rmSync,
	readFileSync,
	readdirSync,
	writeFileSync,
} from 'node:fs';
import { homedir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { requireNode24 } from './node-guard.mjs';

requireNode24('install-claude-rules');

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const dest = join(homedir(), '.claude', 'snail');
const memory = join(homedir(), '.claude', 'CLAUDE.md');

// The dest dir is snail-owned; clear only the rule files we ship.
mkdirSync(dest, { recursive: true });
for (const f of readdirSync(dest)) {
	if (f.endsWith('.md')) rmSync(join(dest, f));
}

/** Strip a leading --- frontmatter block. */
function withoutFrontmatter(text) {
	const lines = text.split('\n');
	if (lines[0] !== '---') return text;
	const end = lines.indexOf('---', 1);
	return end === -1 ? text : lines.slice(end + 1).join('\n');
}

for (const f of readdirSync(join(repoRoot, 'rules'))) {
	if (!f.endsWith('.md')) continue;
	writeFileSync(
		join(dest, f),
		withoutFrontmatter(readFileSync(join(repoRoot, 'rules', f), 'utf8')),
	);
}

let mem = '';
try {
	mem = readFileSync(memory, 'utf8');
} catch {
	// CLAUDE.md does not exist yet; it is created below.
}
const copied = readdirSync(dest).filter((f) => f.endsWith('.md'));
// Drop @snail/ links to rules that no longer ship; keep all other lines.
mem = mem
	.split('\n')
	.filter(
		(l) => !l.trimStart().startsWith('@snail/') || copied.includes(l.slice('@snail/'.length)),
	)
	.join('\n');
if (mem !== '' && !mem.endsWith('\n')) mem += '\n';
for (const f of copied) {
	const line = `@snail/${f}`;
	if (!mem.split('\n').includes(line)) mem += `${line}\n`;
}
writeFileSync(memory, mem);

console.log(`Installed rules into ${dest} and linked them from ${memory}`);
