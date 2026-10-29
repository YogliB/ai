#!/usr/bin/env node
/**
 * sync-devin-plugin: sync the canonical root skills/ and rules/ into the
 * Devin plugin, which must be self-contained: git-subdir installs fetch only
 * plugins/snail/, so a symlink to ../../skills never resolves there.
 *
 * Usage: node scripts/sync-devin-plugin.mjs [--check]
 */
import {
	cpSync,
	existsSync,
	mkdirSync,
	mkdtempSync,
	readFileSync,
	readdirSync,
	rmSync,
	statSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, relative } from 'node:path';
import { execFileSync } from 'node:child_process';
import { requireNode24 } from './node-guard.mjs';

requireNode24('sync-devin-plugin');

const root = execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim();
const plugin = join(root, 'plugins', 'snail');

/** Copy skills/snail-* and rules/*.md into dst. Returns [skillCount, ruleCount]. */
function syncAll(dst) {
	for (const sub of ['skills', 'rules']) {
		rmSync(join(dst, sub), { recursive: true, force: true });
		mkdirSync(join(dst, sub), { recursive: true });
	}
	let count = 0;
	for (const d of readdirSync(join(root, 'skills'))) {
		if (!d.startsWith('snail-') || !statSync(join(root, 'skills', d)).isDirectory()) continue;
		cpSync(join(root, 'skills', d), join(dst, 'skills', d), { recursive: true });
		count++;
	}
	let rcount = 0;
	for (const f of readdirSync(join(root, 'rules'))) {
		if (!f.endsWith('.md')) continue;
		cpSync(join(root, 'rules', f), join(dst, 'rules', f));
		rcount++;
	}
	return [count, rcount];
}

/** All files under dir, as relative paths. */
function filesUnder(dir, base = dir) {
	if (!existsSync(dir)) return [];
	const out = [];
	for (const e of readdirSync(dir, { withFileTypes: true })) {
		const p = join(dir, e.name);
		if (e.isDirectory()) out.push(...filesUnder(p, base));
		else out.push(relative(base, p));
	}
	return out.sort();
}

/** First difference between two directory trees, or null. */
function dirDiff(a, b) {
	const fa = filesUnder(a);
	const fb = filesUnder(b);
	if (fa.join('\n') !== fb.join('\n')) {
		const onlyA = fa
			.filter((f) => !fb.includes(f))
			.map((f) => `only in ${relative(root, a)}: ${f}`);
		const onlyB = fb
			.filter((f) => !fa.includes(f))
			.map((f) => `only in ${relative(root, b)}: ${f}`);
		return [...onlyA, ...onlyB].slice(0, 20).join('\n');
	}
	for (const f of fa) {
		if (readFileSync(join(a, f)).compare(readFileSync(join(b, f))) !== 0) {
			return `${relative(root, a)}/${f} and ${relative(root, b)}/${f} differ`;
		}
	}
	return null;
}

if (process.argv[2] === '--check') {
	const tmp = mkdtempSync(join(tmpdir(), 'sync-devin-plugin-'));
	syncAll(tmp);
	let status = 0;
	for (const sub of ['skills', 'rules']) {
		const diff = dirDiff(join(tmp, sub), join(plugin, sub));
		if (diff) {
			console.error(`sync-devin-plugin: plugins/snail/${sub} is out of sync with ${sub}/:`);
			console.error(diff);
			status = 1;
		}
	}
	rmSync(tmp, { recursive: true, force: true });
	if (status === 0) console.log('sync-devin-plugin: plugin copies are in sync');
	process.exit(status);
}

const [count, rcount] = syncAll(plugin);
console.log(`sync-devin-plugin: synced ${count} skills, ${rcount} rules to plugins/snail/`);
