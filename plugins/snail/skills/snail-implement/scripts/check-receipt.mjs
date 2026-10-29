#!/usr/bin/env node
/**
 * check-receipt: validate a receipt produced by run-with-receipt.
 *
 * A receipt proves a passing check: right version, recorded command, exit
 * code 0, result pass, timestamps, git metadata and captured output.
 * --head additionally binds the receipt to the current commit when git is
 * available, and skips cleanly when it is not.
 *
 * Usage: check-receipt.mjs <receipt> [--head]
 */
import { existsSync, readFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { spawnSync } from 'node:child_process';
import yaml from './vendor/js-yaml.mjs';
import { requireNode24 } from './node-guard.mjs';

requireNode24('check-receipt');

function usage() {
	console.error('usage: check-receipt.mjs <receipt> [--head]');
	process.exit(2);
}

const argv = process.argv.slice(2);
if (argv.length < 1 || argv.length > 2) usage();
let receipt = argv[0];
if (receipt.startsWith('-')) receipt = `./${receipt}`;
const checkHead = argv.length === 2 ? (argv[1] === '--head' ? true : usage()) : false;

if (!existsSync(receipt)) {
	console.error(`check-receipt: no such file: ${receipt}`);
	process.exit(1);
}

/** Fail validation with a message. */
function fail(msg) {
	console.error(`check-receipt: ${receipt}: ${msg}`);
	process.exit(1);
}

let doc;
try {
	doc = yaml.load(readFileSync(receipt, 'utf8'));
} catch (e) {
	fail(`not valid YAML: ${e.message.split('\n')[0]}`);
}
if (doc === null || typeof doc !== 'object' || Array.isArray(doc))
	fail('receipt must be a YAML mapping');

/** Field as a string ('' when missing). */
function get(key) {
	const v = doc[key];
	return v === undefined || v === null ? '' : String(v);
}

if (get('receipt-version') !== '2') fail('missing or unsupported receipt-version');
const cmd = doc.command;
if (
	!(Array.isArray(cmd)
		? cmd.length && cmd.every((c) => typeof c === 'string' && c !== '')
		: get('command'))
)
	fail('missing command');
const code = get('exit-code');
if (!code) fail('missing exit-code');
if (get('result') !== 'pass') fail('result is not pass');
if (code !== '0') fail(`exit-code is ${code}, not 0`);
if (!get('started-at')) fail('missing started-at');
if (!get('finished-at')) fail('missing finished-at');
const head = get('git-head');
if (!head) fail('missing git-head');
if (!('output' in doc)) fail('missing output');

if (checkHead) {
	const g = spawnSync('git', ['-C', dirname(receipt), 'rev-parse', 'HEAD'], { encoding: 'utf8' });
	if (g.status === 0) {
		const current = g.stdout.trim();
		if (head !== current) fail(`receipt was recorded on ${head}, current HEAD is ${current}`);
	} else {
		console.error('check-receipt: no git here; --head check skipped');
	}
}

console.log(`check-receipt: ${receipt} is a valid passing receipt`);
