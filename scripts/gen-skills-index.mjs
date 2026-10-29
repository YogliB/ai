#!/usr/bin/env node
/**
 * gen-skills-index: keep the skills list in rules/snail.md (between the
 * skills:start / skills:end markers) in sync with the skills/ directory.
 *
 * Usage: node scripts/gen-skills-index.mjs [--check]
 */
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { requireNode24 } from './node-guard.mjs';

requireNode24('gen-skills-index');

const root = execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim();
const file = join(root, 'rules', 'snail.md');
const START = '<!-- skills:start -->';
const END = '<!-- skills:end -->';

/** name + first sentence of the description from a SKILL.md frontmatter. */
function skillLine(path) {
	const lines = readFileSync(path, 'utf8').split('\n');
	if (lines[0] !== '---') return null;
	let name = '';
	let desc = '';
	for (const line of lines.slice(1)) {
		if (line === '---') break;
		if (line.startsWith('name: ')) name = line.slice('name: '.length);
		if (line.startsWith('description: ')) desc = line.slice('description: '.length);
	}
	const i = desc.indexOf('. ');
	if (i > 0) desc = desc.slice(0, i);
	desc = desc.replace(/\.$/, '');
	return name && desc ? `- \`${name}\` — ${desc}` : null;
}

// Sort full paths (not bare dir names) so ordering matches the legacy shell glob.
const list = readdirSync(join(root, 'skills'))
	.filter((d) => d.startsWith('snail-') && existsSync(join(root, 'skills', d, 'SKILL.md')))
	.map((d) => join(root, 'skills', d, 'SKILL.md'))
	.sort()
	.map((f) => skillLine(f))
	.filter(Boolean);

const current = readFileSync(file, 'utf8').split('\n');
const startIdx = current.indexOf(START);
const endIdx = current.indexOf(END);
if (
	startIdx === -1 ||
	endIdx === -1 ||
	startIdx >= endIdx ||
	current.indexOf(START, startIdx + 1) !== -1 ||
	current.indexOf(END, endIdx + 1) !== -1
) {
	console.error('gen-skills-index: markers missing or out of order in rules/snail.md');
	process.exit(1);
}

const out = [...current.slice(0, startIdx + 1), '', ...list, '', ...current.slice(endIdx)].join(
	'\n',
);

if (process.argv[2] === '--check') {
	if (readFileSync(file, 'utf8') !== out) {
		console.error(
			'gen-skills-index: skill list in rules/snail.md is out of date; run node scripts/gen-skills-index.mjs',
		);
		const tmp = mkdtempSync(join(tmpdir(), 'gen-skills-index-'));
		writeFileSync(join(tmp, 'out'), out);
		try {
			execFileSync('diff', [file, join(tmp, 'out')], {
				stdio: ['ignore', 'pipe', 'inherit'],
			});
		} catch (e) {
			const lines = (e.stdout ?? '').toString().split('\n').slice(0, 20).join('\n');
			console.error(lines);
		}
		rmSync(tmp, { recursive: true, force: true });
		process.exit(1);
	}
	console.log('gen-skills-index: skill list is up to date');
	process.exit(0);
}

writeFileSync(file, out);
console.log('gen-skills-index: updated rules/snail.md');
