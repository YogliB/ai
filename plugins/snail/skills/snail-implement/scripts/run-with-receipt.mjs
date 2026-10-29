#!/usr/bin/env node
/**
 * run-with-receipt: run a command and record a receipt for it.
 *
 * The receipt is a YAML file capturing the command, exit code, result,
 * timestamps, git metadata and the last 30 output lines. A check without a
 * valid passing receipt did not happen.
 *
 * Usage: run-with-receipt.mjs <receipts-dir> <label> -- <command...>
 */
import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import yaml from './vendor/js-yaml.mjs';
import { requireNode24 } from './node-guard.mjs';

requireNode24('run-with-receipt');

function usage() {
	console.error('usage: run-with-receipt.mjs <receipts-dir> <label> -- <command...>');
	process.exit(2);
}

const argv = process.argv.slice(2);
if (argv.length < 4) usage();
let [dir, label, sep, ...command] = argv;
if (dir.startsWith('-')) dir = `./${dir}`;
if (!label) usage();
if (!/^[A-Za-z0-9._-]+$/.test(label)) {
	console.error(
		`run-with-receipt: label may only contain letters, digits, dot, dash, underscore: ${label}`,
	);
	process.exit(2);
}
if (sep !== '--' || command.length < 1) usage();

mkdirSync(dir, { recursive: true });

const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\..*/, 'Z').replace('T', 'T');
const startS = Math.floor(Date.now() / 1000);
const started = new Date().toISOString().replace(/\.\d+Z$/, 'Z');

const r = spawnSync(command[0], command.slice(1), {
	encoding: 'utf8',
	maxBuffer: 64 * 1024 * 1024,
});
const code = r.status ?? 1;
const out = `${r.stdout ?? ''}${r.stderr ?? ''}${r.error ? String(r.error) : ''}`;

const endS = Math.floor(Date.now() / 1000);
const ended = new Date().toISOString().replace(/\.\d+Z$/, 'Z');

/** git metadata, or the literal 'none' when git is unavailable. */
function git(args) {
	const g = spawnSync('git', args, { encoding: 'utf8' });
	return g.status === 0 ? g.stdout.trim() : 'none';
}

const receipt = {
	'receipt-version': 2,
	label,
	'exit-code': code,
	result: code === 0 ? 'pass' : 'fail',
	'started-at': started,
	'finished-at': ended,
	'duration-seconds': endS - startS,
	'git-head': git(['rev-parse', 'HEAD']),
	'git-branch': git(['rev-parse', '--abbrev-ref', 'HEAD']),
	cwd: process.cwd(),
	command,
	output: out.split('\n').slice(-30).join('\n').replace(/\n$/, ''),
};

const path = join(dir, `${stamp}-${label}-${process.pid}.receipt`);
writeFileSync(path, yaml.dump(receipt, { lineWidth: -1, noRefs: true }));
console.error(`run-with-receipt: receipt written to ${path}`);
process.exit(code);
