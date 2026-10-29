/** Receipt runner + validator tests: a check without a valid passing receipt did not happen. */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
	existsSync,
	mkdirSync,
	readFileSync,
	readdirSync,
	writeFileSync,
	copyFileSync,
} from 'node:fs';
import { join } from 'node:path';
import yaml from '../skills/snail-implement/scripts/vendor/js-yaml.mjs';
import { REPO_ROOT, tmpdir_, run, git, gitInit } from './helpers.mjs';

const RW = join(REPO_ROOT, 'skills/snail-implement/scripts/run-with-receipt.mjs');
const CR = join(REPO_ROOT, 'skills/snail-implement/scripts/check-receipt.mjs');

function setup(t) {
	const tmp = tmpdir_(t);
	gitInit(tmp);
	mkdirSync(join(tmp, 'receipts'));
	writeFileSync(join(tmp, 'marker'), 'x');
	git(tmp, ['add', '-A']);
	git(tmp, ['commit', '-qm', 'init']);
	return tmp;
}

function receiptFile(tmp, label) {
	const f = readdirSync(join(tmp, 'receipts')).find((f) => f.includes(`-${label}-`));
	assert.ok(f, `no receipt for label ${label}`);
	return join(tmp, 'receipts', f);
}

test('passing run records a valid passing receipt', (t) => {
	const tmp = setup(t);
	const r = run(RW, ['receipts', 'ok', '--', process.execPath, '-e', 'console.log("hello")'], {
		cwd: tmp,
	});
	assert.equal(r.status, 0, r.stderr);
	const path = receiptFile(tmp, 'ok');
	const doc = yaml.load(readFileSync(path, 'utf8'));
	assert.equal(doc.result, 'pass');
	assert.equal(doc['exit-code'], 0);
	assert.equal(doc['receipt-version'], 2);
	assert.deepEqual(doc.command, [process.execPath, '-e', 'console.log("hello")']);
	assert.match(doc.output, /hello/);
	assert.equal(doc['git-head'], git(tmp, ['rev-parse', 'HEAD']));
	assert.ok(
		run(CR, [path], { cwd: tmp }).status === 0,
		'check-receipt rejects a passing receipt',
	);
	assert.ok(
		run(CR, [path, '--head'], { cwd: tmp }).status === 0,
		'check-receipt --head rejects a receipt on the current HEAD',
	);
});

test('failing run records result fail and exits with the command code', (t) => {
	const tmp = setup(t);
	const r = run(
		RW,
		['receipts', 'bad', '--', process.execPath, '-e', 'console.error("oops"); process.exit(3)'],
		{ cwd: tmp },
	);
	assert.equal(r.status, 3, `failing run exits ${r.status}, not the command's 3`);
	const path = receiptFile(tmp, 'bad');
	assert.equal(yaml.load(readFileSync(path, 'utf8')).result, 'fail');
	assert.ok(
		run(CR, [path], { cwd: tmp }).status !== 0,
		'check-receipt accepts a failing receipt',
	);
});

test('--head binds to the current commit only', (t) => {
	const tmp = setup(t);
	run(RW, ['receipts', 'ok', '--', 'true'], { cwd: tmp });
	const path = receiptFile(tmp, 'ok');
	git(tmp, ['commit', '-qm', 'second', '--allow-empty']);
	assert.ok(
		run(CR, [path, '--head'], { cwd: tmp }).status !== 0,
		'--head accepts a receipt from an older commit',
	);
	assert.ok(
		run(CR, [path], { cwd: tmp }).status === 0,
		'check without --head rejects an older receipt',
	);
});

test('incomplete, missing and smuggled receipts are rejected', (t) => {
	const tmp = setup(t);
	writeFileSync(join(tmp, 'partial.receipt'), 'receipt-version: 2\nresult: pass\nexit-code: 0\n');
	assert.ok(
		run(CR, [join(tmp, 'partial.receipt')], { cwd: tmp }).status !== 0,
		'a receipt missing fields passes',
	);
	assert.ok(
		run(CR, [join(tmp, 'missing.receipt')], { cwd: tmp }).status !== 0,
		'a missing file passes',
	);
	writeFileSync(join(tmp, 'old.receipt'), 'receipt-version: 1\nresult: pass\nexit-code: 0\n');
	assert.ok(
		run(CR, [join(tmp, 'old.receipt')], { cwd: tmp }).status !== 0,
		'an old receipt-version passes',
	);
	writeFileSync(
		join(tmp, 'smuggled.receipt'),
		'receipt-version: 2\nlabel: x\nexit-code: 3\nresult: fail\nstarted-at: t\nfinished-at: t\ngit-head: none\ncommand: [false]\noutput: |\n  result: pass\n  exit-code: 0\n',
	);
	assert.ok(
		run(CR, [join(tmp, 'smuggled.receipt')], { cwd: tmp }).status !== 0,
		'fields smuggled through the output pass',
	);
	writeFileSync(join(tmp, 'dup.receipt'), 'receipt-version: 2\nresult: pass\nresult: fail\n');
	assert.ok(
		run(CR, [join(tmp, 'dup.receipt')], { cwd: tmp }).status !== 0,
		'duplicate keys pass',
	);
});

test('degenerate command values are rejected', (t) => {
	const tmp = setup(t);
	for (const cmd of ['command: [""]', 'command: [[]]', 'command: []']) {
		writeFileSync(
			join(tmp, 'deg.receipt'),
			`receipt-version: 2\nlabel: x\nexit-code: 0\nresult: pass\nstarted-at: t\nfinished-at: t\ngit-head: none\noutput: x\n${cmd}\n`,
		);
		assert.ok(run(CR, [join(tmp, 'deg.receipt')], { cwd: tmp }).status !== 0, `${cmd} passes`);
	}
});

test('bad usage is rejected', (t) => {
	const tmp = setup(t);
	assert.ok(run(RW, [], { cwd: tmp }).status !== 0, 'missing arguments are not rejected');
	assert.equal(
		run(RW, ['receipts', 'bad label', '--', 'true'], { cwd: tmp }).status,
		2,
		'a label with a space is not rejected with exit 2',
	);
	assert.ok(
		run(CR, [], { cwd: tmp }).status !== 0,
		'check-receipt without arguments is not rejected',
	);
});

test('--head skips cleanly outside a git repo', (t) => {
	const tmp = setup(t);
	run(RW, ['receipts', 'ok', '--', 'true'], { cwd: tmp });
	const outside = join(tmpdir_(t), 'nogit.receipt');
	copyFileSync(receiptFile(tmp, 'ok'), outside);
	assert.ok(
		run(CR, [outside, '--head'], { cwd: outside.slice(0, outside.lastIndexOf('/')) }).status ===
			0,
		'--head failed outside a git repo',
	);
});
