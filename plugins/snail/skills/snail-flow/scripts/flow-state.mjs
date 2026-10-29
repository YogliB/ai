#!/usr/bin/env node
/**
 * flow-state: stage-gate state machine for snail-flow.
 *
 * Tracks a flow's runbook (runbook.yaml), validates its structure and the
 * artifacts each row produces, and advances the cursor when a row's
 * requirements are met. See docs/ARCHITECTURE.md#gates.
 *
 * Usage: flow-state.mjs check <dir> | init <dir> --slug=<s> --goal=<g> [--size=light|full] [--at=<row>] | advance <dir> [--skip|--receipts=a,b|--result=|--valid=|--decision=|--note=] | note <dir> <text...> | set <dir> <key>=<value>
 */
import {
	existsSync,
	mkdirSync,
	readFileSync,
	readdirSync,
	renameSync,
	rmSync,
	writeFileSync,
	realpathSync,
} from 'node:fs';
import { appendFileSync } from 'node:fs';
import { basename, dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import yaml from './vendor/js-yaml.mjs';
import { requireNode24 } from './node-guard.mjs';

requireNode24('flow-state');

const ROWS_FULL = ['0', '1', '1r', '2', '2r', '3', '4', '5', '6'];
const ROWS_LIGHT = ['2', '3', '5', '6'];
const RUNBOOK_VERSION = 4;

const SELF_DIR = dirname(fileURLToPath(import.meta.url));
const CHECK_RECEIPT = resolve(SELF_DIR, '../../snail-implement/scripts/check-receipt.mjs');

/** Fail with a message on stderr and an exit code (default 1). */
function die(msg, code = 1) {
	console.error(`flow-state: ${msg}`);
	process.exit(code);
}

function usage() {
	die(
		'usage: flow-state.mjs check <dir> | init <dir> --slug=<s> --goal=<g> [--size=light|full] [--at=<row>] | advance <dir> [--skip|--receipts=a,b|--result=|--valid=|--decision=|--note=] | note <dir> <text...> | set <dir> <key>=<value>',
		2,
	);
}

/** Artifact filename a row produces (review rows reuse their artifact row). */
function artifact(row) {
	switch (row) {
		case '0':
			return '0 - EXPLORE.yaml';
		case '1':
		case '1r':
			return '1 - ALTERNATIVES.yaml';
		case '2':
		case '2r':
			return '2 - PLANNING.yaml';
		case '3':
			return '3 - IMPLEMENTATION.yaml';
		case '4':
			return '4 - REVIEW.yaml';
		case '5':
			return '5 - VERIFY.yaml';
		case '6':
			return '6 - PR.yaml';
	}
}

/** Human-readable phase name for a row. */
function pname(row) {
	switch (row) {
		case '0':
			return 'Explore';
		case '1':
			return 'Alternatives';
		case '1r':
			return 'Alternatives review';
		case '2':
			return 'Planning';
		case '2r':
			return 'Plan review';
		case '3':
			return 'Implementation';
		case '4':
			return 'Review';
		case '5':
			return 'Verify';
		case '6':
			return 'PR';
	}
}

/**
 * True only for a plain YAML mapping (not null, a scalar, a sequence, a Date,
 * a Buffer, or any other non-plain object). Prototype-based, so a mapping with
 * an own `constructor` key still counts as a mapping.
 */
const isMap = (v) =>
	v !== null && typeof v === 'object' && Object.getPrototypeOf(v) === Object.prototype;

/** Read and parse the runbook, dying with a clear message on any problem. */
function readRunbook(dir) {
	const rbPath = join(dir, 'runbook.yaml');
	if (!existsSync(rbPath))
		die(`runbook missing: ${rbPath} (legacy runbook/runbook.json/RUNBOOK.md is not supported)`);
	let rb;
	try {
		rb = yaml.load(readFileSync(rbPath, 'utf8'));
	} catch (e) {
		die(`runbook is not valid YAML: ${e.message.split('\n')[0]}`);
	}
	if (!isMap(rb)) die('runbook must be a YAML mapping');
	return rb;
}

/** Write the runbook atomically (tmp file + rename). */
function writeRunbook(dir, rb) {
	const rbPath = join(dir, 'runbook.yaml');
	const tmp = `${rbPath}.tmp.${process.pid}`;
	try {
		writeFileSync(tmp, yaml.dump(rb, { lineWidth: -1, noRefs: true }));
		renameSync(tmp, rbPath);
	} catch (e) {
		rmSync(tmp, { force: true });
		die(`cannot write ${rbPath}: ${e.message}`);
	}
}

/** Scalar field of the runbook, as a string ('' when missing). */
function get(rb, key) {
	const v = rb[key];
	return v === undefined || v === null ? '' : String(v);
}

/** Field of a tracked row (rows.<row>.<field>), as a string ('' when missing). */
function fget(rb, row, field) {
	const rows = rb.rows && typeof rb.rows === 'object' ? rb.rows : {};
	const r = rows[row];
	if (r === null || typeof r !== 'object') return '';
	const v = r[field];
	return v === undefined || v === null ? '' : String(v);
}

/** Set a top-level or f.<row>.<field> runbook key and persist. */
function setKv(dir, rb, key, value) {
	if (value.includes('\n')) die(`value for ${key} contains a newline`, 2);
	const RESERVED = new Set(['__proto__', 'constructor', 'prototype']);
	const m = key.match(/^f\.([^.]+)\.([^.]+)$/);
	if (m) {
		if (RESERVED.has(m[1]) || RESERVED.has(m[2])) die(`reserved key in ${key}`, 2);
		if (!isMap(rb.rows)) rb.rows = {};
		if (!Object.hasOwn(rb.rows, m[1]) || !isMap(rb.rows[m[1]])) rb.rows[m[1]] = {};
		rb.rows[m[1]][m[2]] = value;
	} else {
		if (RESERVED.has(key)) die(`reserved key ${key}`, 2);
		rb[key] = value;
	}
	writeRunbook(dir, rb);
}

/** Rows of this flow by size (missing size defaults to full, like before). */
function rowsOf(rb) {
	return get(rb, 'size') === 'light' ? ROWS_LIGHT : ROWS_FULL;
}

function member(x, list) {
	return list.includes(x);
}

/** Rows before `at`, in flow order. */
function before(rows, at) {
	const out = [];
	for (const r of rows) {
		if (r === at) break;
		out.push(r);
	}
	return out;
}

/** Rows after `at`, in flow order. */
function after(rows, at) {
	const idx = rows.indexOf(at);
	return idx === -1 ? [] : rows.slice(idx + 1);
}

const ERRS = [];
function err(msg) {
	ERRS.push(msg);
}

/** git metadata for a directory, or null when git is unavailable/fails. */
function gitHead(dir) {
	const r = spawnSync('git', ['-C', dir, 'rev-parse', 'HEAD'], { encoding: 'utf8' });
	return r.status === 0 ? r.stdout.trim() : null;
}

/** Read a receipt's git-head field; '' when missing/unparseable. */
function receiptGitHead(path) {
	try {
		const r = yaml.load(readFileSync(path, 'utf8'));
		if (r && typeof r === 'object' && r['git-head']) return String(r['git-head']);
	} catch {}
	return '';
}

/** Non-blocking warning when a valid receipt was recorded on another commit. */
function warnStaleReceipt(dir, rel) {
	const rh = receiptGitHead(join(dir, rel));
	if (rh === '' || rh === 'none') return;
	const cur = gitHead(dir);
	if (!cur || rh === cur) return;
	const rhs = rh.slice(0, 8);
	const curs = cur.slice(0, 8);
	const anc = spawnSync('git', ['-C', dir, 'merge-base', '--is-ancestor', rh, cur]);
	if (anc.status === 0) {
		const n = spawnSync('git', ['-C', dir, 'rev-list', '--count', `${rh}..${cur}`], {
			encoding: 'utf8',
		}).stdout.trim();
		console.error(
			`flow-state: warning: ${rel} was recorded ${n} commit(s) behind current HEAD (${rhs} -> ${curs}); re-run the check if code changed since`,
		);
	} else {
		console.error(
			`flow-state: warning: ${rel} was recorded on ${rhs}, not an ancestor of current HEAD (${curs}); re-run the check if code changed since`,
		);
	}
}

/** Validate one cited receipt path; returns an error string or ''. */
function badReceipt(dir, rel) {
	if (
		rel.startsWith('/') ||
		rel === '..' ||
		rel.startsWith('../') ||
		rel.endsWith('/..') ||
		rel.includes('/../')
	) {
		return `receipt path must stay inside the flow dir: ${rel}`;
	}
	if (!existsSync(join(dir, rel))) return `missing receipt: ${rel}`;
	if (!existsSync(CHECK_RECEIPT))
		return `receipt validator missing: ${CHECK_RECEIPT} (install snail-implement)`;
	const r = spawnSync(process.execPath, [CHECK_RECEIPT, join(dir, rel)], { encoding: 'utf8' });
	return r.status === 0 ? '' : `receipt did not pass: ${rel}`;
}

/** Validate a comma-separated receipt list, warning on stale valid ones. */
function collectReceiptErrs(dir, list) {
	const errs = [];
	for (const p of list.split(',')) {
		const m = badReceipt(dir, p);
		if (m) errs.push(m);
		else warnStaleReceipt(dir, p);
	}
	return errs;
}

/** Receipt requirements shared by rows 3 and 5. */
function receiptsOk(dir, rb, row) {
	const list = fget(rb, row, 'receipts');
	if (!list) {
		err(`row ${row} cites no receipts`);
		return;
	}
	if (!existsSync(CHECK_RECEIPT)) {
		err(`row ${row}: receipt validator missing: ${CHECK_RECEIPT} (install snail-implement)`);
		return;
	}
	const errs = collectReceiptErrs(dir, list);
	if (errs.length) err(`row ${row}: ${errs.join('\n')}`);
}

/** Enforce that every completed row satisfied its gate. */
function rowOk(dir, rb, row) {
	const a = artifact(row);
	if (fget(rb, row, 'skipped') === '1' || fget(rb, row, 'skipped') === 'true') {
		if (row !== '1r' && row !== '2r' && existsSync(join(dir, a)))
			err(`row ${row} skipped but ${a} exists`);
		return;
	}
	switch (row) {
		case '1r':
		case '2r':
			if (fget(rb, row, 'valid') !== '0') err(`row ${row} passed without valid=0`);
			break;
		case '3':
			receiptsOk(dir, rb, row);
			break;
		case '5':
			receiptsOk(dir, rb, row);
			if (fget(rb, 5, 'result') !== 'pass') err('row 5 passed without result=pass');
			break;
		case '4': {
			const res = fget(rb, 4, 'result');
			if (res !== 'clean' && res !== 'findings-fixed')
				err(`row 4 passed with invalid result '${res}'`);
			if (fget(rb, 4, 'valid') !== '0') err('row 4 passed without valid=0');
			break;
		}
		case '2':
			if (fget(rb, 2, 'decision') !== 'proceed') err('row 2 passed without decision=proceed');
			break;
	}
	if (row !== '1r' && row !== '2r' && !existsSync(join(dir, a)))
		err(`row ${row} passed but ${a} is missing`);
}

/** Load runbook + derived state for check/advance. */
function load(dir) {
	if (!existsSync(dir)) die(`no such directory: ${dir}`);
	const rb = readRunbook(dir);
	const ver = get(rb, 'runbook-version');
	if (ver !== String(RUNBOOK_VERSION))
		die(`runbook-version is '${ver}', expected ${RUNBOOK_VERSION}`);
	return rb;
}

/** Structural validation of the runbook and the artifacts on disk. */
function validate(dir, rb) {
	const rows = rowsOf(rb);
	const at = get(rb, 'at');
	const slug = get(rb, 'slug');
	if (!slug || !/^[a-z0-9-]+$/.test(slug) || slug.startsWith('-') || slug.endsWith('-'))
		err(`invalid slug '${slug}'`);
	const size = get(rb, 'size');
	if (size !== 'light' && size !== 'full') err(`invalid size '${size}'`);
	if (rb.rows !== undefined && !isMap(rb.rows)) err('rows must be a mapping');
	if (rb.notes !== undefined && !Array.isArray(rb.notes)) err('notes must be a list');
	const status = get(rb, 'status');
	if (!['in-progress', 'completed', 'blocked', 'diverged'].includes(status))
		err(`invalid status '${status}'`);
	if (!member(at, [...rows, 'done'])) err(`at '${at}' is not a row of this flow`);
	if (at === 'done') {
		if (status !== 'completed') err(`at is done but status is '${status}'`);
	} else if (status === 'completed') {
		err(`status is completed but at is '${at}'`);
	}
	for (const r of before(rows, at)) rowOk(dir, rb, r);
	const reachedFiles = [artifact(at), ...before(rows, at).map(artifact)];
	for (const r of after(rows, at)) {
		const a = artifact(r);
		if (reachedFiles.includes(a)) continue;
		if (existsSync(join(dir, a))) err(`${a} exists but row ${r} has not been reached`);
	}
	for (const f of readdirSync(dir)) {
		if (
			!/^[0-9].*\.(yaml|md)$/.test(f) &&
			!f.startsWith('pr-') &&
			f !== 'runbook' &&
			f !== 'runbook.json' &&
			f !== 'RUNBOOK.md'
		)
			continue;
		if (!rows.some((r) => artifact(r) === f)) err(`unexpected file: ${f}`);
	}
	for (const f of readdirSync(dir)) {
		if (!/^[0-9].*\.yaml$/.test(f)) continue;
		if (!rows.some((r) => artifact(r) === f)) continue;
		try {
			yaml.load(readFileSync(join(dir, f), 'utf8'));
		} catch (e) {
			err(`${f} is not valid YAML: ${e.message.split('\n')[0]}`);
		}
	}
}

function printErrs(dir) {
	for (const line of ERRS.join('\n').split('\n')) {
		if (line) console.error(`flow-state: ${dir}: ${line}`);
	}
}

function cmdCheck(dir) {
	const rb = load(dir);
	validate(dir, rb);
	console.log(`flow: ${basename(dir)}`);
	console.log(`size: ${get(rb, 'size')}`);
	if (ERRS.length) {
		console.log('status: error');
		printErrs(dir);
		process.exit(1);
	}
	const at = get(rb, 'at');
	console.log('status: ok');
	console.log(`at: ${at}`);
	if (at === 'done') {
		console.log('next: none');
		console.log('next-phase: flow complete');
	} else {
		console.log(`next: ${at}`);
		console.log(`next-phase: ${pname(at)}`);
	}
}

const giEscape = (seg) =>
	seg.replace(/[\\*?[\]]/g, (c) => `\\${c}`).replace(/^[!#]/, (c) => `\\${c}`);

const shQuote = (s) => `'${s.replace(/'/g, `'\\''`)}'`;

function cmdInit(dir, args) {
	let slug = '',
		goal = '',
		size = 'full',
		at = '',
		atGiven = false;
	for (const a of args) {
		if (a.startsWith('--slug=')) slug = a.slice(7);
		else if (a.startsWith('--goal=')) goal = a.slice(7);
		else if (a.startsWith('--size=')) size = a.slice(7);
		else if (a.startsWith('--at=')) {
			at = a.slice(5);
			atGiven = true;
		} else usage();
	}
	if (`${slug}${goal}`.includes('\n')) die('init: newlines are not allowed', 2);
	if (!slug || !/^[a-z0-9-]+$/.test(slug) || slug.startsWith('-') || slug.endsWith('-'))
		die(`init: invalid or missing slug '${slug}'`, 2);
	if (!goal) die('init: --goal is required', 2);
	let allowed;
	if (size === 'light') allowed = ROWS_LIGHT;
	else if (size === 'full') allowed = ROWS_FULL;
	else die('init: --size must be light or full', 2);
	if (atGiven) {
		if (!at) die('init: --at requires a row', 2);
		if (!member(at, allowed)) die(`init: --at '${at}' is not a row of a ${size} flow`, 2);
		if (at === '1r' || at === '2r')
			die('init: --at must be an artifact row, not a review row', 2);
	} else {
		at = allowed[0];
	}
	if (existsSync(join(dir, 'runbook.yaml')))
		die(`init: ${join(dir, 'runbook.yaml')} already exists`);
	const flowsdir = dirname(dir);
	const agentsdir = dirname(flowsdir);
	if (basename(flowsdir) === 'flows' && basename(agentsdir) === '.agents') {
		mkdirSync(agentsdir, { recursive: true });
		const common = spawnSync('git', ['-C', agentsdir, 'rev-parse', '--git-common-dir'], {
			encoding: 'utf8',
		});
		if (common.status === 0 && common.stdout.trim()) {
			const excl = join(resolve(agentsdir, common.stdout.trim()), 'info', 'exclude');
			const top = spawnSync('git', ['-C', agentsdir, 'rev-parse', '--show-toplevel'], {
				encoding: 'utf8',
			});
			let rule = '',
				rel = '';
			if (top.status === 0 && top.stdout.trim()) {
				rel = relative(top.stdout.trim(), join(realpathSync(agentsdir), 'flows'));
				if (
					rel &&
					rel !== '..' &&
					!rel.startsWith(`..${sep}`) &&
					!isAbsolute(rel) &&
					!rel.includes('\n')
				)
					rule = `${rel.split(sep).map(giEscape).join('/')}/`;
			}
			if (rule) {
				const hasRule =
					existsSync(excl) && readFileSync(excl, 'utf8').split('\n').includes(rule);
				if (!hasRule) {
					mkdirSync(dirname(excl), { recursive: true });
					ensureNl(excl);
					appendFileSync(excl, `${rule}\n`);
				}
			}
			const tracked = spawnSync('git', ['-C', agentsdir, 'ls-files', 'flows'], {
				encoding: 'utf8',
			});
			if (tracked.status === 0 && tracked.stdout.trim()) {
				console.error(
					`init: warning: ${flowsdir} already has tracked files; ignore rules will not hide them (git rm -r --cached ${shQuote(rel || flowsdir)} to untrack)`,
				);
			}
		}
	}
	mkdirSync(dir, { recursive: true });
	const rb = {
		'runbook-version': RUNBOOK_VERSION,
		slug,
		status: 'in-progress',
		goal,
		size,
		at,
	};
	const skipped = [];
	for (const r of allowed) {
		if (r === at) break;
		skipped.push(r);
	}
	if (skipped.length) {
		rb.rows = {};
		for (const r of skipped) rb.rows[r] = { skipped: true, note: 'standalone entry' };
	}
	writeRunbook(dir, rb);
	console.log(`init: ${join(dir, 'runbook.yaml')}`);
}

/** Append a trailing newline to a file missing one. */
function ensureNl(path) {
	if (existsSync(path)) {
		const buf = readFileSync(path);
		if (buf.length && buf[buf.length - 1] !== 10) appendFileSync(path, '\n');
	}
}

function cmdAdvance(dir, args) {
	const rb = load(dir);
	validate(dir, rb);
	if (ERRS.length) {
		printErrs(dir);
		die('advance: runbook failed check; repair before advancing');
	}
	const status = get(rb, 'status');
	if (status === 'completed') die('advance: flow is already completed');
	if (status !== 'in-progress')
		die(`advance: flow is ${status}; use set status=in-progress to resume`);
	const rows = rowsOf(rb);
	const at = get(rb, 'at');
	if (!member(at, rows)) die(`advance: nothing to advance (at is '${at}')`);
	const a = artifact(at);
	let skip = false,
		vReceipts = '',
		vResult = '',
		vValid = '',
		vDecision = '',
		vNote = '';
	for (const arg of args) {
		if (arg === '--skip') skip = true;
		else if (arg.startsWith('--receipts=')) vReceipts = arg.slice(11);
		else if (arg.startsWith('--result=')) vResult = arg.slice(9);
		else if (arg.startsWith('--valid=')) vValid = arg.slice(8);
		else if (arg.startsWith('--decision=')) vDecision = arg.slice(11);
		else if (arg.startsWith('--note=')) vNote = arg.slice(7);
		else die(`advance: unknown flag ${arg.split('=')[0]}`, 2);
	}
	if (`${vReceipts}${vResult}${vValid}${vDecision}${vNote}`.includes('\n'))
		die('advance: newlines are not allowed', 2);
	if (skip) {
		if (at !== '5') die('advance: --skip is only valid on row 5 (verification blocked)', 2);
		if (!vNote) die('advance: --skip requires --note=<reason>', 2);
		if (vReceipts || vResult || vValid || vDecision)
			die('advance: --skip accepts only --note', 2);
		if (existsSync(join(dir, a))) die(`advance: ${a} exists; delete it or advance normally`);
	} else {
		if (!existsSync(join(dir, a))) die(`advance: ${a} is missing`);
		let allowedFlags = [];
		switch (at) {
			case '1r':
			case '2r':
				allowedFlags = ['valid'];
				break;
			case '2':
				allowedFlags = ['decision'];
				break;
			case '3':
				allowedFlags = ['receipts'];
				break;
			case '4':
				allowedFlags = ['result', 'valid'];
				break;
			case '5':
				allowedFlags = ['result', 'receipts'];
				break;
		}
		for (const [f, v] of [
			['receipts', vReceipts],
			['result', vResult],
			['valid', vValid],
			['decision', vDecision],
		]) {
			if (!v) continue;
			if (!member(f, allowedFlags)) die(`advance: --${f} is not accepted on row ${at}`, 2);
		}
		switch (at) {
			case '1r':
			case '2r':
				if (vValid !== '0') die(`advance: row ${at} requires --valid=0`, 2);
				break;
			case '2':
				if (vDecision !== 'proceed') die('advance: row 2 requires --decision=proceed', 2);
				break;
			case '3': {
				if (!vReceipts) die(`advance: row ${at} requires --receipts=<files>`, 2);
				const errs = advanceReceiptsCheck(dir, vReceipts);
				if (errs.length) die(`advance: ${errs.join('\n')}`);
				break;
			}
			case '5': {
				if (vResult !== 'pass') die('advance: row 5 requires --result=pass', 2);
				if (!vReceipts) die(`advance: row ${at} requires --receipts=<files>`, 2);
				const errs = advanceReceiptsCheck(dir, vReceipts);
				if (errs.length) die(`advance: ${errs.join('\n')}`);
				break;
			}
			case '4':
				if (vResult !== 'clean' && vResult !== 'findings-fixed')
					die('advance: row 4 requires --result=clean|findings-fixed', 2);
				if (vValid !== '0') die('advance: row 4 requires --valid=0', 2);
				break;
		}
	}
	const next = after(rows, at)[0];
	delete rb.rows?.[at];
	if (!isMap(rb.rows)) rb.rows = {};
	if (skip) {
		rb.rows[at] = { skipped: true };
	} else {
		const entry = {};
		if (vReceipts) entry.receipts = vReceipts;
		if (vResult) entry.result = vResult;
		if (vValid) entry.valid = vValid;
		if (vDecision) entry.decision = vDecision;
		if (Object.keys(entry).length) rb.rows[at] = entry;
	}
	if (vNote) {
		if (!rb.rows[at]) rb.rows[at] = {};
		rb.rows[at].note = vNote;
	}
	if (Object.keys(rb.rows).length === 0) delete rb.rows;
	rb.at = next ?? 'done';
	rb.status = next ? 'in-progress' : 'completed';
	writeRunbook(dir, rb);
	console.log(`advanced to ${next ?? 'done'}`);
}

/** Receipt gate for advance: validator presence + per-receipt checks. */
function advanceReceiptsCheck(dir, list) {
	if (!existsSync(CHECK_RECEIPT))
		die(`advance: receipt validator missing: ${CHECK_RECEIPT} (install snail-implement)`);
	return collectReceiptErrs(dir, list);
}

function cmdNote(dir, rb, words) {
	if (!words.length) usage();
	const text = words.join(' ');
	if (text.includes('\n')) die('note: newlines are not allowed', 2);
	if (rb.notes !== undefined && !Array.isArray(rb.notes)) {
		die('note: runbook notes is not a list; fix or remove it by editing runbook.yaml');
	}
	if (!Array.isArray(rb.notes)) rb.notes = [];
	rb.notes.push(text);
	writeRunbook(dir, rb);
	console.log('note recorded');
}

function cmdSet(dir, rb, pair) {
	if (!pair.includes('=')) usage();
	const key = pair.slice(0, pair.indexOf('='));
	const val = pair.slice(pair.indexOf('=') + 1);
	if (key === 'note') die("set: 'note' is append-only; use note", 2);
	if (!key || !/^[a-zA-Z0-9._-]+$/.test(key)) die(`set: invalid key '${key}'`, 2);
	if (key === 'size') {
		if (val !== 'light' && val !== 'full') die('set: size must be light or full', 2);
		for (const f of readdirSync(dir)) {
			if (/^[0-9].*\.yaml$/.test(f) || f.startsWith('pr-'))
				die('set: size= is only safe before artifacts exist');
		}
		const loaded = load(dir);
		const allowed = val === 'light' ? ROWS_LIGHT : ROWS_FULL;
		loaded.at = allowed[0];
		loaded.size = val;
		writeRunbook(dir, loaded);
		console.log(`set size ${val}`);
		return;
	}
	setKv(dir, rb, key, val);
	console.log(`set ${key} ${val}`);
}

/** Strip a leading-dash hazard from a directory argument. */
function dirarg(d) {
	return d.startsWith('-') ? `./${d}` : d;
}

const argv = process.argv.slice(2);
if (argv.length < 1) usage();
const [cmd, ...rest] = argv;
switch (cmd) {
	case 'check':
		if (rest.length !== 1) usage();
		cmdCheck(dirarg(rest[0]));
		break;
	case 'init':
		if (rest.length < 1) usage();
		cmdInit(dirarg(rest[0]), rest.slice(1));
		break;
	case 'advance':
		if (rest.length < 1) usage();
		cmdAdvance(dirarg(rest[0]), rest.slice(1));
		break;
	case 'note': {
		if (rest.length < 2) usage();
		const dir = dirarg(rest[0]);
		if (!existsSync(join(dir, 'runbook.yaml')))
			die(`runbook missing: ${join(dir, 'runbook.yaml')}`);
		cmdNote(dir, readRunbook(dir), rest.slice(1));
		break;
	}
	case 'set': {
		if (rest.length !== 2) usage();
		const dir = dirarg(rest[0]);
		if (!existsSync(join(dir, 'runbook.yaml')))
			die(`runbook missing: ${join(dir, 'runbook.yaml')}`);
		cmdSet(dir, readRunbook(dir), rest[1]);
		break;
	}
	default:
		usage();
}
