/** flow-state tests: the snail-flow stage-gate state machine. */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
	existsSync,
	mkdirSync,
	readdirSync,
	readFileSync,
	renameSync,
	rmSync,
	writeFileSync,
} from 'node:fs';
import { basename, join } from 'node:path';
import yaml from '../skills/snail-flow/scripts/vendor/js-yaml.mjs';
import { REPO_ROOT, tmpdir_, run, git, gitInit } from './helpers.mjs';

const FS = join(REPO_ROOT, 'skills/snail-flow/scripts/flow-state.mjs');
const RW = join(REPO_ROOT, 'skills/snail-implement/scripts/run-with-receipt.mjs');

/** Parsed runbook.yaml of a flow dir. */
function rb(dir) {
	return yaml.load(readFileSync(join(dir, 'runbook.yaml'), 'utf8'));
}

function fsRun(dir, args, opts) {
	return run(FS, args, opts);
}

/** check must pass and report status ok. */
function ok(t, dir, cwd, msg) {
	const r = fsRun(dir, ['check', dir], { cwd });
	assert.equal(r.status, 0, `${msg}: ${r.stderr}`);
	assert.match(r.stdout, /status: ok/, msg);
	return r;
}

/** check must fail. */
function bad(t, dir, cwd, msg) {
	const r = fsRun(dir, ['check', dir], { cwd });
	assert.notEqual(r.status, 0, msg);
	return r;
}

function artifact(dir, name, content = 'goal: x\n') {
	writeFileSync(join(dir, name), content);
}

function makeReceipt(t, dir, label, cwd) {
	assert.equal(run(RW, [join(dir, 'receipts'), label, '--', 'true'], { cwd }).status, 0);
	const f = readdirSync(join(dir, 'receipts')).find((f) => f.includes(`-${label}-`));
	assert.ok(f, `no ${label} receipt`);
	return `receipts/${f}`;
}

test('full flow: init, gates, receipts, warnings, reopen, skip, blocked, sizes', (t) => {
	const tmp = tmpdir_(t);
	gitInit(tmp);
	git(tmp, ['commit', '-qm', 'init', '--allow-empty']);
	const D = '.agents/flows/snail-demo';

	// init
	assert.equal(
		fsRun(D, ['init', D, '--slug=demo', '--goal=test flow'], { cwd: tmp }).status,
		0,
		'init failed',
	);
	assert.ok(existsSync(join(tmp, D, 'runbook.yaml')), 'init did not write runbook.yaml');
	assert.ok(
		readFileSync(join(tmp, '.git/info/exclude'), 'utf8').split('\n').includes('.agents/flows/'),
		'init did not add .agents/flows/ to .git/info/exclude',
	);
	assert.ok(
		!existsSync(join(tmp, '.agents/.gitignore')),
		'init created .agents/.gitignore, which would enter git status',
	);
	assert.equal(
		git(tmp, ['status', '--porcelain']),
		'',
		'a freshly introduced .agents tree showed up in git status',
	);
	assert.notEqual(
		fsRun(D, ['init', D, '--slug=demo', '--goal=x'], { cwd: tmp }).status,
		0,
		'init over an existing runbook succeeded',
	);

	// fresh check
	let r = ok(t, join(tmp, D), tmp, 'fresh runbook does not check');
	assert.match(r.stdout, /at: 0/);
	assert.match(r.stdout, /next-phase: Explore/);

	// row 0
	assert.notEqual(
		fsRun(D, ['advance', D], { cwd: tmp }).status,
		0,
		'advance accepted a missing artifact',
	);
	artifact(join(tmp, D), '0 - EXPLORE.yaml');
	assert.equal(fsRun(D, ['advance', D], { cwd: tmp }).status, 0, 'advance row 0 failed');
	assert.equal(rb(join(tmp, D)).at, '1', 'cursor did not move to 1');

	// rows 1 and 1r
	artifact(join(tmp, D), '1 - ALTERNATIVES.yaml');
	assert.equal(fsRun(D, ['advance', D], { cwd: tmp }).status, 0, 'advance row 1 failed');
	assert.notEqual(
		fsRun(D, ['advance', D], { cwd: tmp }).status,
		0,
		'row 1r advanced without --valid=0',
	);
	assert.equal(
		fsRun(D, ['advance', D, '--valid=0'], { cwd: tmp }).status,
		0,
		'advance row 1r failed',
	);
	assert.equal(rb(join(tmp, D)).rows['1r'].valid, '0', 'row 1r valid not recorded');

	// rows 2 and 2r
	artifact(join(tmp, D), '2 - PLANNING.yaml');
	assert.notEqual(
		fsRun(D, ['advance', D, '--decision=split'], { cwd: tmp }).status,
		0,
		'decision split accepted',
	);
	assert.equal(
		fsRun(D, ['advance', D, '--decision=proceed'], { cwd: tmp }).status,
		0,
		'advance row 2 failed',
	);
	assert.equal(
		fsRun(D, ['advance', D, '--valid=0'], { cwd: tmp }).status,
		0,
		'advance row 2r failed',
	);

	// row 3 with receipts
	artifact(join(tmp, D), '3 - IMPLEMENTATION.yaml');
	assert.notEqual(
		fsRun(D, ['advance', D], { cwd: tmp }).status,
		0,
		'row 3 advanced without receipts',
	);
	assert.notEqual(
		fsRun(D, ['advance', D, '--receipts=receipts/nope.receipt'], { cwd: tmp }).status,
		0,
		'row 3 accepted a missing receipt',
	);
	assert.notEqual(
		fsRun(D, ['advance', D, '--receipts=../outside.receipt'], { cwd: tmp }).status,
		0,
		'row 3 accepted a receipt outside the flow dir',
	);
	const R = makeReceipt(t, join(tmp, D), 'impl', tmp);
	assert.equal(
		fsRun(D, ['advance', D, `--receipts=${R}`], { cwd: tmp }).status,
		0,
		'advance row 3 with receipt failed',
	);

	renameSync(join(tmp, D, R), join(tmp, D, `${R}.keep`));
	r = bad(t, join(tmp, D), tmp, 'check passed with a missing cited receipt');
	assert.match(r.stderr, /missing receipt/, 'check did not report the missing receipt');
	renameSync(join(tmp, D, `${R}.keep`), join(tmp, D, R));
	r = ok(t, join(tmp, D), tmp, 'check failed after restoring receipt');
	assert.doesNotMatch(r.stderr, /warning/, 'fresh receipt triggered a stale warning');

	// stale receipt warning after HEAD moves
	git(tmp, ['commit', '-qm', 'move-head', '--allow-empty']);
	r = fsRun(D, ['check', D], { cwd: tmp });
	assert.equal(r.status, 0, 'stale receipt blocked the check');
	assert.match(r.stdout, /status: ok/, 'stale receipt flipped the status');
	assert.match(r.stderr, /warning: .*behind current HEAD/, 'no stale-receipt warning on check');

	// diverged receipt warning on an orphan branch
	const B = git(tmp, ['branch', '--show-current']);
	git(tmp, ['checkout', '-q', '--orphan', 'diverged']);
	git(tmp, ['commit', '-qm', 'diverged', '--allow-empty']);
	r = fsRun(D, ['check', D], { cwd: tmp });
	assert.equal(r.status, 0, 'diverged receipt blocked the check');
	assert.match(r.stdout, /status: ok/, 'diverged receipt flipped the status');
	assert.match(r.stderr, /warning: .*not an ancestor/, 'no diverged-receipt warning on check');
	git(tmp, ['checkout', '-q', B]);
	git(tmp, ['branch', '-qD', 'diverged']);

	// row 4
	assert.notEqual(
		fsRun(D, ['advance', D, `--receipts=${R}`], { cwd: tmp }).status,
		0,
		'row 4 accepted a result-less advance',
	);
	artifact(join(tmp, D), '4 - REVIEW.yaml');
	assert.notEqual(
		fsRun(D, ['advance', D, '--result=clean'], { cwd: tmp }).status,
		0,
		'row 4 advanced without --valid=0',
	);
	assert.notEqual(
		fsRun(D, ['advance', D, '--result=bogus', '--valid=0'], { cwd: tmp }).status,
		0,
		'row 4 accepted a bogus result',
	);
	assert.equal(
		fsRun(D, ['advance', D, '--result=findings-fixed', '--valid=0'], { cwd: tmp }).status,
		0,
		'advance row 4 failed',
	);

	// row 5
	artifact(join(tmp, D), '5 - VERIFY.yaml');
	assert.notEqual(
		fsRun(D, ['advance', D, '--result=fail', `--receipts=${R}`], { cwd: tmp }).status,
		0,
		'row 5 accepted result=fail',
	);
	const V = makeReceipt(t, join(tmp, D), 'verify', tmp);
	assert.equal(
		fsRun(D, ['advance', D, '--result=pass', `--receipts=${V}`], { cwd: tmp }).status,
		0,
		'advance row 5 failed',
	);

	// row 6 completes the flow
	artifact(join(tmp, D), '6 - PR.yaml');
	assert.equal(fsRun(D, ['advance', D], { cwd: tmp }).status, 0, 'advance row 6 failed');
	assert.equal(rb(join(tmp, D)).at, 'done', 'flow did not complete');
	assert.equal(rb(join(tmp, D)).status, 'completed', 'status not completed');
	r = ok(t, join(tmp, D), tmp, 'completed flow does not check');
	assert.match(r.stdout, /next: none/, 'completed flow still has a next');
	assert.notEqual(
		fsRun(D, ['advance', D], { cwd: tmp }).status,
		0,
		'advance on a completed flow succeeded',
	);

	// reopen: cursor back, later artifacts must be removed first
	assert.equal(fsRun(D, ['set', D, 'at=4'], { cwd: tmp }).status, 0, 'set at failed');
	assert.equal(
		fsRun(D, ['set', D, 'status=in-progress'], { cwd: tmp }).status,
		0,
		'set status failed',
	);
	bad(t, join(tmp, D), tmp, 'stale later artifacts tolerated after reopen');
	rmSync(join(tmp, D, '5 - VERIFY.yaml'));
	rmSync(join(tmp, D, '6 - PR.yaml'));
	r = ok(t, join(tmp, D), tmp, 'reopened flow does not check');
	assert.match(r.stdout, /at: 4/, 'reopen did not move cursor back to 4');
	assert.equal(
		fsRun(D, ['advance', D, '--result=clean', '--valid=0'], { cwd: tmp }).status,
		0,
		're-advance of reopened row failed',
	);
	artifact(join(tmp, D), '5 - VERIFY.yaml');
	assert.equal(
		fsRun(D, ['advance', D, '--result=pass', `--receipts=${V}`], { cwd: tmp }).status,
		0,
		're-advance row 5 failed',
	);
	artifact(join(tmp, D), '6 - PR.yaml');
	assert.equal(fsRun(D, ['advance', D], { cwd: tmp }).status, 0, 're-advance row 6 failed');

	// note
	assert.equal(
		fsRun(D, ['note', D, 'reopened for a test'], { cwd: tmp }).status,
		0,
		'note failed',
	);
	assert.ok(rb(join(tmp, D)).notes.includes('reopened for a test'), 'note was not recorded');

	// skip flow
	const D2 = '.agents/flows/snail-skip';
	assert.equal(
		fsRun(D2, ['init', D2, '--slug=skip', '--goal=g', '--at=5'], { cwd: tmp }).status,
		0,
		'init --at=5 failed',
	);
	assert.equal(
		rb(join(tmp, D2)).rows['3'].skipped,
		true,
		'init --at did not mark earlier rows skipped',
	);
	assert.notEqual(
		fsRun(D2, ['advance', D2, '--skip'], { cwd: tmp }).status,
		0,
		'skip accepted without a note',
	);
	assert.notEqual(
		fsRun(D2, ['advance', D2, '--skip', '--note=x', '--receipts=y'], { cwd: tmp }).status,
		0,
		'skip accepted extra flags',
	);
	assert.equal(
		fsRun(D2, ['advance', D2, '--skip', '--note=verify blocked'], { cwd: tmp }).status,
		0,
		'skip advance on row 5 failed',
	);
	assert.equal(rb(join(tmp, D2)).rows['5'].skipped, true, 'row 5 skip not recorded');
	assert.equal(
		rb(join(tmp, D2)).rows['5'].note,
		'verify blocked',
		'row 5 skip note not recorded',
	);
	r = fsRun(D2, ['check', D2], { cwd: tmp });
	assert.equal(r.status, 0, `check after skip failed: ${r.stderr}`);
	assert.match(r.stdout, /at: 6/, 'skip did not move cursor to 6');
	artifact(join(tmp, D2), '6 - PR.yaml');
	assert.equal(
		fsRun(D2, ['advance', D2], { cwd: tmp }).status,
		0,
		'advance row 6 after skip failed',
	);
	assert.notEqual(
		fsRun(D2, ['advance', D2, '--skip', '--note=x'], { cwd: tmp }).status,
		0,
		'skip accepted on a completed flow',
	);
	assert.notEqual(
		fsRun(D2, ['note', D2, 'bad\nnote'], { cwd: tmp }).status,
		0,
		'note accepted a newline',
	);
	assert.notEqual(
		fsRun(D2, ['set', D2, 'at=one\ntwo'], { cwd: tmp }).status,
		0,
		'set accepted a newline value',
	);
	assert.notEqual(
		fsRun(D2, ['set', D2, 'f.__proto__.x=y'], { cwd: tmp }).status,
		0,
		'set accepted a __proto__ row key',
	);
	assert.notEqual(
		fsRun(D2, ['set', D2, '__proto__=y'], { cwd: tmp }).status,
		0,
		'set accepted a __proto__ top-level key',
	);
	assert.notEqual(
		fsRun(D2, ['set', D2, 'f.0.__proto__=y'], { cwd: tmp }).status,
		0,
		'set accepted a __proto__ field key',
	);

	// malformed rows are re-initialized: no uncaught TypeError, no silent drop
	const malformed = yaml.load(readFileSync(join(tmp, D2, 'runbook.yaml'), 'utf8'));
	malformed.rows['0'] = null;
	malformed.rows['1r'] = ['a', 'b'];
	writeFileSync(join(tmp, D2, 'runbook.yaml'), yaml.dump(malformed));
	assert.equal(
		fsRun(D2, ['set', D2, 'f.0.note=nullrow'], { cwd: tmp }).status,
		0,
		'set crashed on a null row',
	);
	assert.equal(
		fsRun(D2, ['set', D2, 'f.1r.note=arrayrow'], { cwd: tmp }).status,
		0,
		'set crashed on an array row',
	);
	const repaired = rb(join(tmp, D2));
	assert.equal(repaired.rows['0'].note, 'nullrow', 'null row write was dropped');
	assert.equal(repaired.rows['1r'].note, 'arrayrow', 'array row write was dropped');

	// rows as a sequence or a non-plain-object scalar: re-initialized, never silently dropped
	const malformed2 = rb(join(tmp, D2));
	malformed2.rows = ['a', 'b'];
	writeFileSync(join(tmp, D2, 'runbook.yaml'), yaml.dump(malformed2));
	assert.equal(
		fsRun(D2, ['set', D2, 'f.1r.note=seqrow'], { cwd: tmp }).status,
		0,
		'set crashed on a sequence rows container',
	);
	assert.equal(rb(join(tmp, D2)).rows['1r'].note, 'seqrow', 'sequence rows write was dropped');
	const malformed3 = rb(join(tmp, D2));
	malformed3.rows = { 0: new Date('2024-01-01') };
	writeFileSync(join(tmp, D2, 'runbook.yaml'), yaml.dump(malformed3));
	assert.equal(
		fsRun(D2, ['set', D2, 'f.0.note=daterow'], { cwd: tmp }).status,
		0,
		'set crashed on a timestamp row',
	);
	assert.equal(rb(join(tmp, D2)).rows['0'].note, 'daterow', 'timestamp row write was dropped');

	// a row named constructor must not wipe the rows map; sibling fields survive set
	const malformed4 = rb(join(tmp, D2));
	malformed4.rows = { constructor: { note: 'keepme' }, 0: { result: 'keep' } };
	writeFileSync(join(tmp, D2, 'runbook.yaml'), yaml.dump(malformed4));
	assert.equal(
		fsRun(D2, ['set', D2, 'f.0.note=landed'], { cwd: tmp }).status,
		0,
		'set failed with a constructor-named row present',
	);
	const preserved = rb(join(tmp, D2));
	assert.equal(preserved.rows['constructor'].note, 'keepme', 'constructor-named row was wiped');
	assert.equal(preserved.rows['0'].result, 'keep', 'sibling field was wiped');
	assert.equal(preserved.rows['0'].note, 'landed', 'write did not land');

	// a non-mapping runbook document dies loudly instead of silently dropping writes
	writeFileSync(join(tmp, D2, 'runbook.yaml'), '2024-01-01\n');
	assert.notEqual(
		fsRun(D2, ['set', D2, 'slug=x'], { cwd: tmp }).status,
		0,
		'set on a timestamp runbook exited 0',
	);

	// error flow: stray files, unreached artifacts, legacy junk, flag misuse
	const D3 = '.agents/flows/snail-errs';
	assert.equal(
		fsRun(D3, ['init', D3, '--slug=errs', '--goal=g', '--at=1'], { cwd: tmp }).status,
		0,
		'init --at=1 failed',
	);
	artifact(join(tmp, D3), '9 - STRAY.yaml');
	bad(t, join(tmp, D3), tmp, 'stray numbered artifact accepted');
	rmSync(join(tmp, D3, '9 - STRAY.yaml'));
	artifact(join(tmp, D3), '6 - PR.yaml');
	bad(t, join(tmp, D3), tmp, 'artifact for an unreached row accepted');
	rmSync(join(tmp, D3, '6 - PR.yaml'));
	writeFileSync(join(tmp, D3, 'runbook.json'), '{}\n');
	bad(t, join(tmp, D3), tmp, 'legacy runbook.json tolerated');
	rmSync(join(tmp, D3, 'runbook.json'));
	ok(t, join(tmp, D3), tmp, 'clean dir does not check');
	assert.notEqual(
		fsRun('x', ['init', '.agents/flows/snail-bad', '--slug=bad', '--goal=g', '--at=1r'], {
			cwd: tmp,
		}).status,
		0,
		'init --at=1r accepted',
	);
	artifact(join(tmp, D3), '1 - ALTERNATIVES.yaml');
	assert.notEqual(
		fsRun(D3, ['advance', D3, '--result=clean'], { cwd: tmp }).status,
		0,
		'row 1 accepted a flag it does not use',
	);
	assert.notEqual(
		fsRun(D3, ['set', D3, 'size=lihgt'], { cwd: tmp }).status,
		0,
		"set accepted a typo'd size",
	);
	ok(t, join(tmp, D3), tmp, "typo'd size rejected by set");

	// a legacy non-YAML runbook is rejected with a clear message
	const DLG = join(tmp, '.agents/flows/snail-legacy');
	mkdirSync(DLG, { recursive: true });
	writeFileSync(join(DLG, 'runbook'), 'runbook-version: 3\n');
	r = fsRun(DLG, ['check', DLG], { cwd: tmp });
	assert.notEqual(r.status, 0, 'legacy runbook accepted');
	assert.match(r.stderr, /legacy runbook\/runbook.json\/RUNBOOK.md is not supported/);

	// invalid YAML artifacts are reported
	const DY = '.agents/flows/snail-badyaml';
	assert.equal(fsRun(DY, ['init', DY, '--slug=badyaml', '--goal=g'], { cwd: tmp }).status, 0);
	writeFileSync(join(tmp, DY, '0 - EXPLORE.yaml'), 'a: [unclosed\n');
	r = bad(t, join(tmp, DY), tmp, 'invalid YAML artifact accepted');
	assert.match(r.stderr, /not valid YAML/);

	// legacy .md artifacts are unexpected files
	writeFileSync(join(tmp, D3, '2 - PLANNING.md'), '# legacy\n');
	r = bad(t, join(tmp, D3), tmp, 'legacy numbered .md artifact accepted');
	assert.match(r.stderr, /unexpected file: 2 - PLANNING.md/);
	rmSync(join(tmp, D3, '2 - PLANNING.md'));
	ok(t, join(tmp, D3), tmp, 'clean after removing the legacy artifact');

	// set f.<row>.<field> repairs a row field
	assert.equal(
		fsRun(D3, ['set', D3, 'f.1r.valid=0'], { cwd: tmp }).status,
		0,
		'set f.<row>.<field> failed',
	);
	assert.equal(rb(join(tmp, D3)).rows['1r'].valid, '0', 'dotted set did not land');
	ok(t, join(tmp, D3), tmp, 'check after dotted set');

	// note refuses to wipe a malformed notes field
	const rb3 = rb(join(tmp, D3));
	rb3.notes = 'hand-edited string';
	writeFileSync(join(tmp, D3, 'runbook.yaml'), yaml.dump(rb3, { lineWidth: -1 }));
	r = fsRun(D3, ['note', D3, 'x'], { cwd: tmp });
	assert.notEqual(r.status, 0, 'note wiped a malformed notes field');
	assert.match(r.stderr, /notes is not a list/);
	delete rb3.notes;
	writeFileSync(join(tmp, D3, 'runbook.yaml'), yaml.dump(rb3, { lineWidth: -1 }));

	// light flow
	const DL = '.agents/flows/snail-lite';
	assert.equal(
		fsRun(DL, ['init', DL, '--slug=lite', '--goal=g', '--size=light'], { cwd: tmp }).status,
		0,
		'light init failed',
	);
	assert.equal(rb(join(tmp, DL)).at, '2', 'light flow did not start at row 2');
	artifact(join(tmp, DL), '2 - PLANNING.yaml');
	assert.notEqual(
		fsRun(DL, ['advance', DL], { cwd: tmp }).status,
		0,
		'row 2 advanced without --decision',
	);
	assert.equal(
		fsRun(DL, ['advance', DL, '--decision=proceed'], { cwd: tmp }).status,
		0,
		'light advance row 2 failed',
	);
	artifact(join(tmp, DL), '3 - IMPLEMENTATION.yaml');
	const RL = makeReceipt(t, join(tmp, DL), 'impl', tmp);
	assert.equal(
		fsRun(DL, ['advance', DL, `--receipts=${RL}`], { cwd: tmp }).status,
		0,
		'light advance row 3 failed',
	);
	assert.equal(
		rb(join(tmp, DL)).at,
		'5',
		'light cursor did not jump 3->5 (row 4 must not exist)',
	);
	artifact(join(tmp, DL), '4 - REVIEW.yaml');
	assert.notEqual(
		fsRun(DL, ['check', DL], { cwd: tmp }).status,
		0,
		'light flow tolerated a row-4 artifact',
	);
	rmSync(join(tmp, DL, '4 - REVIEW.yaml'));
	artifact(join(tmp, DL), '5 - VERIFY.yaml');
	assert.equal(
		fsRun(DL, ['advance', DL, '--result=pass', `--receipts=${RL}`], { cwd: tmp }).status,
		0,
		'light advance row 5 failed',
	);
	artifact(join(tmp, DL), '6 - PR.yaml');
	assert.equal(fsRun(DL, ['advance', DL], { cwd: tmp }).status, 0, 'light advance row 6 failed');
	assert.equal(rb(join(tmp, DL)).at, 'done', 'light flow did not complete');

	// blocked flow
	const D4 = '.agents/flows/snail-blocked';
	assert.equal(
		fsRun(D4, ['init', D4, '--slug=blocked', '--goal=x'], { cwd: tmp }).status,
		0,
		'blocked init failed',
	);
	assert.equal(
		fsRun(D4, ['set', D4, 'status=blocked'], { cwd: tmp }).status,
		0,
		'set status=blocked failed',
	);
	r = fsRun(D4, ['advance', D4], { cwd: tmp });
	assert.notEqual(r.status, 0, 'advance ran on a blocked flow');
	assert.match(
		r.stderr,
		/set status=in-progress to resume/,
		'blocked advance did not print the resume hint',
	);
	assert.equal(
		fsRun(D4, ['set', D4, 'status=in-progress'], { cwd: tmp }).status,
		0,
		'set status=in-progress failed',
	);
	artifact(join(tmp, D4), '0 - EXPLORE.yaml');
	assert.equal(fsRun(D4, ['advance', D4], { cwd: tmp }).status, 0, 'advance after resume failed');

	// size switching before artifacts exist
	const D5 = '.agents/flows/snail-size';
	assert.equal(
		fsRun(D5, ['init', D5, '--slug=size', '--goal=x'], { cwd: tmp }).status,
		0,
		'size init failed',
	);
	assert.equal(
		fsRun(D5, ['set', D5, 'size=light'], { cwd: tmp }).status,
		0,
		'set size=light failed',
	);
	assert.equal(rb(join(tmp, D5)).at, '2', 'size=light did not move cursor to row 2');
	ok(t, join(tmp, D5), tmp, 'check after size=light');
	assert.equal(
		fsRun(D5, ['set', D5, 'size=full'], { cwd: tmp }).status,
		0,
		'set size=full failed',
	);
	assert.equal(rb(join(tmp, D5)).at, '0', 'size=full did not move cursor to row 0');
	ok(t, join(tmp, D5), tmp, 'check after size=full');
	artifact(join(tmp, D5), '0 - EXPLORE.yaml');
	assert.notEqual(
		fsRun(D5, ['set', D5, 'size=light'], { cwd: tmp }).status,
		0,
		'set size= ran with artifacts present',
	);
	rmSync(join(tmp, D5, '0 - EXPLORE.yaml'));

	// exclude handling: repo-relative rule, append after a missing trailing
	// newline, never duplicate
	mkdirSync(join(tmp, 'nested/.agents/flows'), { recursive: true });
	writeFileSync(join(tmp, '.git/info/exclude'), 'dist');
	assert.equal(
		fsRun('x', ['init', 'nested/.agents/flows/snail-nl', '--slug=nl', '--goal=x'], { cwd: tmp })
			.status,
		0,
		'init under existing exclude failed',
	);
	const gi = readFileSync(join(tmp, '.git/info/exclude'), 'utf8').split('\n');
	assert.equal(gi[0], 'dist', 'init merged into last exclude line');
	assert.equal(
		gi[1],
		'nested/.agents/flows/',
		'init did not append the repo-relative flows rule after missing newline',
	);
	assert.equal(
		fsRun('x', ['init', 'nested/.agents/flows/snail-nl2', '--slug=nl2', '--goal=x'], {
			cwd: tmp,
		}).status,
		0,
		'second init under existing exclude failed',
	);
	assert.equal(
		readFileSync(join(tmp, '.git/info/exclude'), 'utf8')
			.split('\n')
			.filter((l) => l === 'nested/.agents/flows/').length,
		1,
		'init duplicated the flows rule in exclude',
	);
});

test('init in a ..-prefixed subdir still writes the rule', (t) => {
	const tmp = tmpdir_(t);
	gitInit(tmp);
	git(tmp, ['commit', '-qm', 'init', '--allow-empty']);
	mkdirSync(join(tmp, '..dots/.agents'), { recursive: true });
	assert.equal(
		fsRun('x', ['init', '..dots/.agents/flows/snail-g', '--slug=g', '--goal=x'], {
			cwd: tmp,
		}).status,
		0,
	);
	assert.ok(
		readFileSync(join(tmp, '.git/info/exclude'), 'utf8')
			.split('\n')
			.includes('..dots/.agents/flows/'),
		'rule missing for ..-prefixed in-repo dir',
	);
});

test('init escapes gitignore glob chars in the rule', (t) => {
	const tmp = tmpdir_(t);
	gitInit(tmp);
	git(tmp, ['commit', '-qm', 'init', '--allow-empty']);
	mkdirSync(join(tmp, 'we[ird/.agents'), { recursive: true });
	assert.equal(
		fsRun('x', ['init', 'we[ird/.agents/flows/snail-g', '--slug=g', '--goal=x'], {
			cwd: tmp,
		}).status,
		0,
	);
	const rule = readFileSync(join(tmp, '.git/info/exclude'), 'utf8')
		.split('\n')
		.find((l) => l.includes('flows'));
	assert.equal(rule, 'we\\[ird/.agents/flows/');
	assert.equal(
		spawnSync('git', ['-C', tmp, 'check-ignore', 'we[ird/.agents/flows/snail-g/runbook.yaml'])
			.status,
		0,
		'escaped rule does not match the flow dir',
	);
});

test('tracked-flows warning shell-quotes the flows path', (t) => {
	const tmp = tmpdir_(t);
	gitInit(tmp);
	git(tmp, ['commit', '-qm', 'init', '--allow-empty']);
	mkdirSync(join(tmp, `it's a dir/.agents/flows/snail-t`), { recursive: true });
	writeFileSync(join(tmp, `it's a dir/.agents/flows/snail-t/seed.yaml`), 'x\n');
	git(tmp, ['add', '-A']);
	git(tmp, ['commit', '-qm', 'tracked']);
	const r = fsRun('x', ['init', `it's a dir/.agents/flows/snail-t`, '--slug=t', '--goal=x'], {
		cwd: tmp,
	});
	assert.equal(r.status, 0, r.stderr);
	assert.ok(
		r.stderr.includes(`git rm -r --cached 'it'\\''s a dir/.agents/flows' to untrack`),
		r.stderr,
	);
});

test('init inside .git writes no exclude rule', (t) => {
	const tmp = tmpdir_(t);
	gitInit(tmp);
	git(tmp, ['commit', '-qm', 'init', '--allow-empty']);
	mkdirSync(join(tmp, '.git/.agents'), { recursive: true });
	assert.equal(
		fsRun('x', ['init', '.git/.agents/flows/snail-g', '--slug=g', '--goal=x'], {
			cwd: tmp,
		}).status,
		0,
		'init under .git failed',
	);
	assert.ok(
		!readFileSync(join(tmp, '.git/info/exclude'), 'utf8')
			.split('\n')
			.some((l) => l.includes('flows')),
		'init wrote an exclude rule it could not anchor to the toplevel',
	);
});

test('install paths with spaces resolve the receipt validator', (t) => {
	const base = join(tmpdir_(t), 'dir with spaces');
	mkdirSync(base);
	gitInit(base);
	git(base, ['commit', '-qm', 'init', '--allow-empty']);
	const D = '.agents/flows/snail-space';
	assert.equal(
		run(FS, ['init', D, '--slug=space', '--goal=g', '--size=light'], { cwd: base }).status,
		0,
	);
	writeFileSync(join(base, D, '2 - PLANNING.yaml'), 'goal: g\n');
	assert.equal(run(FS, ['advance', D, '--decision=proceed'], { cwd: base }).status, 0);
	writeFileSync(join(base, D, '3 - IMPLEMENTATION.yaml'), 'goal: g\n');
	const R = makeReceipt(t, join(base, D), 'impl', base);
	assert.equal(
		run(FS, ['advance', D, `--receipts=${R}`], { cwd: base }).status,
		0,
		'receipt gate broke on a path with spaces',
	);
});
