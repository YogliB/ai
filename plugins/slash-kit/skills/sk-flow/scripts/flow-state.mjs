#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const SCHEMA_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'schemas');
const ROWS_SINGLE = ['0', '1', '1r', '2', '2r', '3', '4', '5', '6'];
const ROWS_INITIATIVE = ['0', '1', '1r', '2', '2r'];
const LIGHT_ROWS = ['0', '1', '1r', '2r', '4'];
const ARTIFACT = {
	0: '0 - EXPLORE.md',
	1: '1 - ALTERNATIVES.md',
	'1r': '1 - ALTERNATIVES.md',
	2: '2 - PLANNING.md',
	'2r': '2 - PLANNING.md',
	3: '3 - IMPLEMENTATION.md',
	4: '4 - REVIEW.md',
	5: '5 - VERIFY.md',
	6: '6 - PR.md',
};
const PHASE_NAME = {
	0: 'Explore',
	1: 'Alternatives',
	'1r': 'Alternatives review',
	2: 'Planning',
	'2r': 'Plan review',
	3: 'Implementation',
	4: 'Review',
	5: 'Verify',
	6: 'PR',
};
const FILE_SCHEMA = {
	'0 - EXPLORE.md': ['explore'],
	'1 - ALTERNATIVES.md': ['alternatives'],
	'2 - PLANNING.md': ['plan', 'masterplan'],
	'3 - IMPLEMENTATION.md': ['implementation'],
	'4 - REVIEW.md': ['review'],
	'5 - VERIFY.md': ['verify'],
	'6 - PR.md': ['pr'],
};
const errors = [];
const err = (msg) => errors.push(msg);

const typeOf = (v) => (Array.isArray(v) ? 'array' : v === null ? 'null' : typeof v);
const depsOf = (pr) => (typeOf(pr) === 'object' && Array.isArray(pr.deps) ? pr.deps : []);
const orderOf = (pr) => (typeOf(pr) === 'object' && Number.isInteger(pr.order) ? pr.order : 0);
const isDir = (p) => {
	try {
		return fs.statSync(p).isDirectory();
	} catch {
		return false;
	}
};
const TYPE_OK = {
	object: (v) => typeOf(v) === 'object',
	array: (v) => typeOf(v) === 'array',
	string: (v) => typeof v === 'string',
	integer: (v) => Number.isInteger(v),
	number: (v) => typeof v === 'number',
	boolean: (v) => typeof v === 'boolean',
};

function validate(schema, data, label) {
	if (schema.type && TYPE_OK[schema.type] && !TYPE_OK[schema.type](data)) {
		err(`${label}: expected ${schema.type}, got ${typeOf(data)}`);
		return;
	}
	if (schema.enum && !schema.enum.includes(data))
		err(`${label}: must be one of ${schema.enum.join('|')}, got '${data}'`);
	if (schema.pattern && typeof data === 'string' && !new RegExp(schema.pattern).test(data))
		err(`${label}: '${data}' does not match ${schema.pattern}`);
	if (schema.minimum !== undefined && typeof data === 'number' && data < schema.minimum)
		err(`${label}: ${data} < minimum ${schema.minimum}`);
	if (schema.minItems !== undefined && typeOf(data) === 'array' && data.length < schema.minItems)
		err(`${label}: fewer than ${schema.minItems} items`);
	if (
		schema.minLength !== undefined &&
		typeof data === 'string' &&
		data.length < schema.minLength
	)
		err(`${label}: empty or shorter than ${schema.minLength}`);
	if (typeOf(data) === 'object') {
		for (const k of schema.required || []) if (!(k in data)) err(`${label}: missing '${k}'`);
		for (const [k, v] of Object.entries(data)) {
			const sub =
				typeOf(schema.properties) === 'object' && Object.hasOwn(schema.properties, k)
					? schema.properties[k]
					: undefined;
			if (sub) validate(sub, v, `${label}.${k}`);
			else if (schema.additionalProperties === false) err(`${label}: unexpected key '${k}'`);
			else if (typeOf(schema.additionalProperties) === 'object')
				validate(schema.additionalProperties, v, `${label}.${k}`);
		}
	}
	if (typeOf(data) === 'array' && schema.items)
		data.forEach((v, i) => validate(schema.items, v, `${label}[${i}]`));
}

const loadSchema = (name) => {
	const p = path.join(SCHEMA_DIR, `${name}.schema.json`);
	if (!fs.existsSync(p)) throw new Error(`schema not found: ${p}`);
	return JSON.parse(fs.readFileSync(p, 'utf8'));
};

const readFile = (file, label) => {
	try {
		return { text: fs.readFileSync(file, 'utf8') };
	} catch (e) {
		return { error: `${label}: cannot read ${file}: ${e.message}` };
	}
};

let KNOWN_SCHEMAS;
let RUNBOOK_SCHEMA;
let STATES;
let PR_STATES;
let SLUG_RE;
let FLOW_STATUSES;
function initSchemas() {
	if (RUNBOOK_SCHEMA) return;
	KNOWN_SCHEMAS = new Set(
		fs.readdirSync(SCHEMA_DIR).map((f) => f.replace(/\.schema\.json$/, '')),
	);
	RUNBOOK_SCHEMA = loadSchema('runbook');
	STATES = RUNBOOK_SCHEMA.properties.phases.additionalProperties.properties.state.enum;
	PR_STATES = RUNBOOK_SCHEMA.properties.prs.additionalProperties.properties.state.enum;
	SLUG_RE = new RegExp(RUNBOOK_SCHEMA.properties.slug.pattern);
	FLOW_STATUSES = RUNBOOK_SCHEMA.properties.status.enum;
}

const usage = () => {
	console.error(
		`usage: flow-state.mjs check <dir|file.md> | init <dir> --slug=<s> --goal=<g> [--size=light|full] [--at=<row>] | set <dir> <row> <state(${STATES.join('|')})> [--agent=|--input=|--head=|--summary=|--note=] | set <dir> [--status=|--size=|--goal=|--active-pr=] | pr <dir> <slug> [--repo=|--deps=a,b|--state=|--branch=|--base-sha=|--head=|--notes=|--order=] [--init]`,
		`       pr: once a masterplan exists a new slug must appear in its prs list; --init scaffolds pr-<slug>/runbook.json now (omit only to scaffold it later)`,
	);
	process.exit(2);
};

function rejectFlags(flags, allowed, what) {
	for (const k of Object.keys(flags))
		if (!allowed.includes(k)) {
			console.error(`flow-state: ${what}: unknown or inapplicable flag --${k}`);
			process.exit(2);
		}
}

const readJson = (file, label) => {
	const r = readFile(file, label);
	if (r.error) {
		err(r.error);
		return null;
	}
	try {
		return JSON.parse(r.text);
	} catch (e) {
		err(`${label}: invalid JSON in ${file}: ${e.message}`);
		return null;
	}
};

function writeJson(file, data) {
	const tmp = `${file}.tmp-${process.pid}`;
	fs.writeFileSync(tmp, JSON.stringify(data, null, '\t') + '\n');
	fs.renameSync(tmp, file);
}

function frontmatter(file) {
	let text;
	try {
		text = fs.readFileSync(file, 'utf8');
	} catch {
		return { error: `cannot read ${file}` };
	}
	const lines = text.split('\n');
	if (lines[0] !== '<!--') return { error: "missing frontmatter (file must start with '<!--')" };
	const end = lines.indexOf('-->', 1);
	if (end === -1) return { error: 'unterminated frontmatter' };
	try {
		return { data: JSON.parse(lines.slice(1, end).join('\n')) };
	} catch (e) {
		return { error: `invalid frontmatter JSON: ${e.message}` };
	}
}

function validateArtifact(file, label) {
	const base = path.basename(file);
	const fm = frontmatter(file);
	if (fm.error) return err(`${label}: ${base}: ${fm.error}`);
	const schemaName = fm.data?.schema;
	if (!schemaName) return err(`${label}: ${base}: frontmatter has no 'schema' field`);
	if (!KNOWN_SCHEMAS.has(schemaName)) {
		err(`${label}: ${base}: unknown schema '${schemaName}'`);
		return fm.data;
	}
	let allowed = Object.hasOwn(FILE_SCHEMA, base) ? FILE_SCHEMA[base] : undefined;
	if (base === '2 - PLANNING.md' && /^pr-/.test(path.basename(path.dirname(file))))
		allowed = ['plan'];
	if (allowed && !allowed.includes(schemaName))
		err(
			`${label}: ${base}: schema '${schemaName}' not allowed here (expected ${allowed.join('|')})`,
		);
	try {
		validate(loadSchema(schemaName), fm.data, `${base} frontmatter`);
	} catch (e) {
		err(`${label}: ${base}: ${e.message}`);
	}
	return fm.data;
}

function receiptPasses(file) {
	const got = {};
	let output = false;
	let text;
	try {
		text = fs.readFileSync(file, 'utf8');
	} catch {
		return false;
	}
	for (const line of text.split('\n')) {
		if (line.startsWith('--- output')) {
			output = true;
			break;
		}
		const i = line.indexOf(': ');
		if (i > 0 && got[line.slice(0, i)] === undefined) got[line.slice(0, i)] = line.slice(i + 2);
	}
	if (
		!(
			output &&
			got['receipt-version'] === '1' &&
			!!got.command &&
			got['exit-code'] === '0' &&
			got.result === 'pass' &&
			!!got['started-at'] &&
			!!got['finished-at'] &&
			!!got['git-head']
		)
	)
		return false;
	const dir = path.dirname(file);
	const quiet = { stdio: ['ignore', 'pipe', 'ignore'] };
	try {
		execFileSync('git', ['-C', dir, 'rev-parse', '--git-dir'], quiet);
	} catch {
		return true;
	}
	try {
		execFileSync(
			'git',
			['-C', dir, 'merge-base', '--is-ancestor', got['git-head'], 'HEAD'],
			quiet,
		);
		return true;
	} catch {
		return false;
	}
}

function resolveReceipt(dir, r) {
	const isFile = (p) => {
		try {
			return fs.statSync(p).isFile();
		} catch {
			return false;
		}
	};
	if (path.isAbsolute(r)) return isFile(r) ? r : null;
	let d = path.resolve(dir);
	for (let i = 0; i < 8; i++) {
		const cand = path.join(d, r);
		if (fs.existsSync(cand)) return isFile(cand) ? cand : null;
		const p = path.dirname(d);
		if (p === d) break;
		d = p;
	}
	return null;
}

function validatePhaseSet(rb, dir, expected, label) {
	const phases = typeOf(rb.phases) === 'object' ? rb.phases : {};
	const size = rb.size || 'full';
	if (size === 'light') {
		if (label !== 'runbook') err(`${label}: Size: light is for single-PR runbooks only`);
		for (const row of LIGHT_ROWS)
			if (phases[row]?.state !== 'skipped')
				err(`${label}: Size light requires row ${row} skipped`);
		for (const row of ['2', '3', '6'])
			if (phases[row]?.state === 'skipped')
				err(`${label}: Size light cannot skip row ${row}`);
		for (const row of ['3', '5']) {
			const st = phases[row]?.state;
			if (st !== 'done' && st !== 'diverged') continue;
			const file = path.join(dir, ARTIFACT[row]);
			const fm = fs.existsSync(file) ? frontmatter(file) : {};
			const receipts = fm.data?.receipts;
			if (!Array.isArray(receipts) || receipts.length === 0) {
				err(`${label}: Size light row ${row} artifact cites no receipt`);
				continue;
			}
			for (const r of receipts) {
				if (typeof r !== 'string') {
					err(`${label}: Size light row ${row} cites a non-string receipt entry`);
					continue;
				}
				const p = resolveReceipt(dir, r);
				if (!p) err(`${label}: Size light row ${row} cites a missing receipt: ${r}`);
				else if (!receiptPasses(p))
					err(`${label}: Size light row ${row} cites a receipt that did not pass: ${r}`);
			}
		}
	} else if (size === 'full') {
		const guarded = label === 'runbook' ? ['2', '3', '4', '6'] : ['2', '3', '4'];
		for (const row of guarded)
			if (phases[row]?.state === 'skipped')
				err(`${label}: row ${row} cannot be skipped without Size: light`);
	} else err(`${label}: invalid Size '${size}' (light or full)`);

	for (const id of Object.keys(phases))
		if (!expected.includes(id)) err(`${label}: unexpected row ${id}`);
	for (const row of expected) {
		const ph = phases[row];
		if (typeOf(ph) !== 'object') {
			err(
				`${label}: runbook row ${row} ${ph === undefined ? 'missing' : 'is not an object'}`,
			);
			continue;
		}
		if (!STATES.includes(ph.state)) {
			err(`${label}: row ${row} has invalid state '${ph.state}'`);
			continue;
		}
		if (['skipped', 'diverged', 'blocked'].includes(ph.state) && !ph.note)
			err(`${label}: row ${row} is ${ph.state} without a note`);
		const art = path.join(dir, ARTIFACT[row]);
		const has = fs.existsSync(art);
		if ((ph.state === 'done' || ph.state === 'diverged') && !has)
			err(`${label}: row ${row} is ${ph.state} but ${ARTIFACT[row]} is missing`);
		if (ph.state === 'skipped' && !row.endsWith('r') && has)
			err(`${label}: row ${row} is skipped but ${ARTIFACT[row]} exists`);
	}
	for (const row of ['0', '1', '2', '3', '4', '5', '6']) {
		if (!expected.includes(row)) continue;
		const ph = phases[row];
		if (ph?.state === 'pending' && !ph.reopened && fs.existsSync(path.join(dir, ARTIFACT[row])))
			err(`${label}: ${ARTIFACT[row]} exists but row ${row} is pending`);
	}
	let unfinished = false;
	let strictUnfinished = false;
	for (const row of expected) {
		const ph = phases[row];
		const st = ph?.state;
		if (['done', 'diverged', 'in-progress'].includes(st) && unfinished)
			err(`${label}: row ${row} is ${st} while an earlier row is unfinished`);
		if (['pending', 'blocked', 'in-progress'].includes(st)) {
			strictUnfinished = true;
			if (!ph?.reopened) unfinished = true;
		}
	}
	if (rb.status === 'completed' && strictUnfinished)
		err(`${label}: completed status has unfinished phases`);
	const inprog = expected.filter((r) => phases[r]?.state === 'in-progress');
	if (inprog.length > 1)
		err(`${label}: ${inprog.length} rows are in-progress; at most one allowed`);
}

function checkFiles(dir, expected, label) {
	if (fs.existsSync(path.join(dir, 'RUNBOOK.md')))
		err(`${label}: legacy RUNBOOK.md found next to runbook.json; remove it`);
	const known = new Set(expected.map((r) => ARTIFACT[r]));
	for (const f of fs.readdirSync(dir)) {
		if (/^[0-9].*\.md$/.test(f) && !known.has(f))
			err(`${label}: unexpected artifact file: ${f}`);
	}
}

function strayPrEntries(dir, label) {
	for (const f of fs.readdirSync(dir))
		if (/^pr-/.test(f)) err(`${label}: unexpected pr-* entry: ${f}`);
}

const VERDICT_ROW = {
	'1 - ALTERNATIVES.md': '1r',
	'2 - PLANNING.md': '2r',
	'4 - REVIEW.md': '4',
	'5 - VERIFY.md': '5',
};

function validateArtifacts(dir, expected, label, slug, phases) {
	const seen = new Set();
	for (const row of expected) {
		const file = path.join(dir, ARTIFACT[row]);
		if (seen.has(ARTIFACT[row]) || !fs.existsSync(file)) continue;
		seen.add(ARTIFACT[row]);
		const fm = validateArtifact(file, label);
		if (fm?.slug && slug && fm.slug !== slug)
			err(
				`${label}: ${ARTIFACT[row]} slug '${fm.slug}' does not match runbook slug '${slug}'`,
			);
		const vr = VERDICT_ROW[ARTIFACT[row]];
		if (!fm || !vr || phases?.[vr]?.state !== 'done') continue;
		if ((vr === '1r' || vr === '2r') && typeOf(fm.review) === 'object' && fm.review.valid > 0)
			err(
				`${label}: row ${vr} is done but ${ARTIFACT[vr]} has ${fm.review.valid} unresolved valid findings`,
			);
		if (vr === '4' && fm.result === 'blocked')
			err(`${label}: row 4 is done but ${ARTIFACT['4']} result is 'blocked'`);
		if (vr === '4' && fm.valid > 0)
			err(
				`${label}: row 4 is done but ${ARTIFACT['4']} has ${fm.valid} unresolved valid findings`,
			);
		if (vr === '5' && fm.result && fm.result !== 'pass')
			err(`${label}: row 5 is done but ${ARTIFACT['5']} result is '${fm.result}'`);
	}
}

function loadRunbook(dir, label) {
	const file = path.join(dir, 'runbook.json');
	if (!fs.existsSync(file)) {
		if (fs.existsSync(path.join(dir, 'RUNBOOK.md')))
			err(
				`${label}: legacy runbook format: RUNBOOK.md found. Finish the flow on the previous plugin version or remove RUNBOOK.md and create runbook.json via init`,
			);
		else err(`${label}: runbook.json missing`);
		return null;
	}
	const r = readFile(file, label);
	if (r.error) {
		err(r.error);
		return null;
	}
	let rb;
	try {
		rb = JSON.parse(r.text);
	} catch (e) {
		err(`${label}: invalid JSON in ${file}: ${e.message}`);
		return null;
	}
	const tag = label === 'runbook' ? 'runbook.json' : `${label} runbook.json`;
	validate(loadSchema('runbook'), rb, tag);
	if (typeOf(rb) !== 'object') return null;
	return rb;
}

const nextRow = (rb, expected) => {
	const phases = typeOf(rb.phases) === 'object' ? rb.phases : {};
	return expected.find((r) => ['pending', 'in-progress', 'blocked'].includes(phases[r]?.state));
};

function validateFlow(dir, rb, overrides = {}) {
	if (typeOf(rb) !== 'object') return;
	const base = path.basename(dir);
	const m = base.match(/^pr-(.+)$/);
	const multi = 'prs' in rb || 'active-pr' in rb;
	const label = m ? `PR ${m[1]}` : multi ? 'initiative' : 'runbook';
	if (m || !multi) {
		validatePhaseSet(rb, dir, ROWS_SINGLE, label);
		if (m) {
			if (rb.slug !== m[1])
				err(`${label}: runbook slug '${rb.slug}' does not match directory '${base}'`);
			if ('prs' in rb || 'active-pr' in rb) err(`${label}: runbook is an initiative runbook`);
			for (const r of ['0', '1', '1r'])
				if (rb.phases?.[r]?.state !== 'skipped')
					err(`PR ${m[1]}: row ${r} must be skipped (initiative root)`);
		}
		checkFiles(dir, ROWS_SINGLE, label);
		validateArtifacts(dir, ROWS_SINGLE, label, rb.slug, rb.phases);
		strayPrEntries(dir, label);
		const planPath = path.join(dir, ARTIFACT['2']);
		if (fs.existsSync(planPath)) {
			const fm = frontmatter(planPath).data;
			if (!m && fm?.schema === 'masterplan')
				err(`${label}: masterplan requires an initiative runbook (convert via pr)`);
			else if (fm?.schema === 'plan' && fm?.decision === 'split')
				err(
					m
						? `${label}: plan decision 'split' is not valid in a PR runbook`
						: `${label}: plan decision 'split' requires converting to an initiative`,
				);
		}
		return;
	}
	validatePhaseSet(rb, dir, ROWS_INITIATIVE, 'initiative');
	checkFiles(dir, ROWS_INITIATIVE, 'initiative');
	validateArtifacts(dir, ROWS_INITIATIVE, 'initiative', rb.slug, rb.phases);
	const active = rb['active-pr'];
	if (active === undefined || active === '') err('initiative: active-pr is missing or empty');
	const prs = rb.prs || {};
	const slugs = Object.keys(prs);
	if (slugs.length === 0) err('initiative: the pull requests table has no rows');
	const inProgress = [];
	for (const slug of slugs) {
		const pr = prs[slug];
		if (slug === 'none') err("initiative: 'none' is a reserved PR slug");
		else if (!SLUG_RE.test(slug)) err(`initiative: invalid PR slug '${slug}'`);
		if (typeOf(pr) !== 'object') continue;
		for (const dep of depsOf(pr)) {
			if (dep === slug) err(`initiative: PR ${slug} depends on itself`);
			else if (!Object.hasOwn(prs, dep))
				err(`initiative: PR ${slug} depends on unknown PR '${dep}'`);
			else if (
				['pending', 'blocked'].includes(pr.state) &&
				typeOf(prs[dep]) === 'object' &&
				prs[dep].state === 'canceled'
			)
				err(`initiative: PR ${slug} depends on canceled PR ${dep}`);
			else if (
				pr.state !== 'canceled' &&
				typeOf(prs[dep]) === 'object' &&
				prs[dep].state !== 'canceled' &&
				Number.isInteger(pr.order) &&
				Number.isInteger(prs[dep].order) &&
				prs[dep].order >= pr.order
			)
				err(`initiative: PR ${slug} depends on ${dep} which is not earlier in order`);
		}
		if (!PR_STATES.includes(pr.state))
			err(`initiative: PR ${slug} has invalid state '${pr.state}'`);
		if (pr.state === 'blocked' && !pr.notes)
			err(`initiative: PR ${slug} is blocked without notes`);
		if (pr.state === 'done' && !pr.notes) err(`initiative: PR ${slug} is done without notes`);
		if (pr.state === 'in-progress') inProgress.push(slug);
		const pdir = path.join(dir, `pr-${slug}`);
		const pdirIsDir = isDir(pdir);
		let prb;
		if (pdirIsDir && fs.existsSync(path.join(pdir, 'runbook.json'))) {
			prb = loadRunbook(pdir, `PR ${slug}`);
		} else if (Object.hasOwn(overrides, slug)) {
			prb = overrides[slug];
			validate(RUNBOOK_SCHEMA, prb, `PR ${slug} runbook.json`);
		} else {
			err(`initiative: PR ${slug} has no pr-${slug}/runbook.json`);
			if (pdirIsDir) checkFiles(pdir, ROWS_SINGLE, `PR ${slug}`);
			continue;
		}
		if (!prb || typeOf(prb) !== 'object') continue;
		if (prb.slug !== slug) err(`initiative: PR ${slug} runbook.json slug is '${prb.slug}'`);
		if ('prs' in prb || 'active-pr' in prb)
			err(`initiative: PR ${slug} runbook is an initiative runbook`);
		else {
			validatePhaseSet(prb, pdir, ROWS_SINGLE, `PR ${slug}`);
			for (const r of ['0', '1', '1r'])
				if (prb.phases?.[r]?.state !== 'skipped')
					err(`initiative: PR ${slug} row ${r} must be skipped (initiative root)`);
			if (pdirIsDir) {
				checkFiles(pdir, ROWS_SINGLE, `PR ${slug}`);
				validateArtifacts(pdir, ROWS_SINGLE, `PR ${slug}`, prb.slug, prb.phases);
				strayPrEntries(pdir, `PR ${slug}`);
				const cplan = path.join(pdir, ARTIFACT['2']);
				const cfm = fs.existsSync(cplan) ? frontmatter(cplan).data : null;
				if (cfm?.schema === 'plan' && cfm?.decision === 'split')
					err(
						`initiative: PR ${slug} plan decision 'split' is not valid in a PR runbook`,
					);
			}
			const s6 = typeOf(prb.phases) === 'object' ? prb.phases['6']?.state : undefined;
			if (
				['in-progress', 'pending', 'blocked'].includes(pr.state) &&
				!nextRow(prb, ROWS_SINGLE)
			)
				err(`initiative: PR ${slug} is ${pr.state} but its runbook has no pending rows`);
			if (pr.state === 'done' && s6 !== 'done' && s6 !== 'skipped')
				err(`initiative: PR ${slug} is done but its runbook row 6 is ${s6 || 'missing'}`);
			if (['in-progress', 'pending', 'blocked'].includes(pr.state) && s6 === 'done')
				err(`initiative: PR ${slug} is ${pr.state} but its runbook row 6 is done`);
			if (['in-progress', 'done'].includes(pr.state))
				for (const dep of depsOf(pr))
					if (prs[dep]?.state !== 'done')
						err(
							`initiative: PR ${slug} is ${pr.state} but dependency ${dep} is ${prs[dep]?.state || 'unknown'}`,
						);
		}
	}
	for (const f of fs.readdirSync(dir)) {
		if (!/^pr-/.test(f)) continue;
		if (!isDir(path.join(dir, f))) {
			err(`initiative: ${f} is not a directory`);
			continue;
		}
		const slug = f.slice(3);
		if (!Object.hasOwn(prs, slug))
			err(`initiative: directory ${f} is not in the pull requests table`);
	}
	const orders = slugs
		.map((s) => prs[s])
		.filter((p) => typeOf(p) === 'object' && p.state !== 'canceled')
		.map((p) => p.order)
		.filter((o) => Number.isInteger(o));
	if (new Set(orders).size !== orders.length) err('initiative: duplicate PR order values');
	if (inProgress.length > 1)
		err(`initiative: ${inProgress.length} PRs are in-progress; at most one allowed`);
	else if (inProgress.length === 1) {
		if (active !== inProgress[0])
			err(
				`initiative: Active PR is '${active}' but the in-progress PR is '${inProgress[0]}'`,
			);
	} else if (active !== 'none')
		err(`initiative: Active PR is '${active}' but no PR is in-progress`);
	const initNext = nextRow(rb, ROWS_INITIATIVE);
	if (initNext && active !== 'none' && active !== undefined && active !== '')
		err('initiative: active PR cannot start before initiative phases finish');
	if (rb.status === 'completed')
		for (const slug of slugs)
			if (!['done', 'canceled'].includes(prs[slug]?.state))
				err(`initiative: completed status has unfinished PR ${slug}`);
	const reach = (start, target, seen = new Set()) => {
		for (const d of depsOf(prs[start]))
			if (d === target || (!seen.has(d) && seen.add(d) && reach(d, target, seen)))
				return true;
		return false;
	};
	for (const slug of slugs)
		if (reach(slug, slug)) err(`initiative: PR ${slug} is part of a dependency cycle`);
	const planFile = path.join(dir, ARTIFACT['2']);
	if (fs.existsSync(planFile)) {
		const fm = frontmatter(planFile).data;
		if (fm && fm.schema !== 'masterplan')
			err(`initiative: root ${ARTIFACT['2']} must use schema 'masterplan'`);
		if (fm?.schema === 'masterplan' && Array.isArray(fm.prs)) {
			for (const s of slugs)
				if (prs[s]?.state !== 'canceled' && !fm.prs.includes(s))
					err(`initiative: PR ${s} is not in masterplan prs [${fm.prs.join(',')}]`);
			for (const s of fm.prs)
				if (!Object.hasOwn(overrides, s) && !fs.existsSync(path.join(dir, `pr-${s}`)))
					err(`initiative: masterplan PR ${s} has no pr-${s}/ directory`);
			const live = (s) =>
				Object.hasOwn(prs, s) && typeOf(prs[s]) === 'object' && prs[s].state !== 'canceled';
			const planned = fm.prs.filter(live);
			const sorted = slugs
				.filter((s) => live(s) && fm.prs.includes(s))
				.sort((a, b) => orderOf(prs[a]) - orderOf(prs[b]));
			if (JSON.stringify(planned) !== JSON.stringify(sorted))
				err(
					`initiative: masterplan prs order [${planned.join(',')}] does not match runbook order [${sorted.join(',')}]`,
				);
		}
	}
}

function checkFlow(dir) {
	if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) {
		console.error(`flow-state: no such directory: ${dir}`);
		process.exit(1);
	}
	console.log(`flow: ${path.basename(dir)}`);
	const rb = loadRunbook(dir, 'runbook');
	if (!rb) {
		console.log('status: error');
		for (const e of errors) console.error(`flow-state: ${dir}: ${e}`);
		process.exit(1);
	}
	const multi = 'prs' in rb || 'active-pr' in rb;
	console.log(`mode: ${multi ? 'multi' : 'single'}`);
	validateFlow(dir, rb);
	if (errors.length > 0) finish(dir);
	const active = multi ? rb['active-pr'] : undefined;
	const prs = multi ? rb.prs || {} : {};
	const initNext = nextRow(rb, multi ? ROWS_INITIATIVE : ROWS_SINGLE);
	let target;
	if (multi && !initNext)
		target =
			active && active !== 'none'
				? active
				: Object.keys(prs)
						.sort((a, b) => orderOf(prs[a]) - orderOf(prs[b]))
						.find(
							(s) =>
								prs[s]?.state === 'pending' &&
								depsOf(prs[s]).every((d) => prs[d]?.state === 'done'),
						);
	let prNext;
	if (target) {
		const prb = readJson(path.join(dir, `pr-${target}`, 'runbook.json'), `PR ${target}`);
		if (typeOf(prb) !== 'object') finish(dir);
		prNext = nextRow(prb, ROWS_SINGLE);
		if (!prNext) {
			err(`PR ${target}: runbook has no pending rows`);
			finish(dir);
		}
	}
	console.log('status: ok');
	console.log(`size: ${rb.size || 'full'}`);
	if (multi) console.log(`active-pr: ${active || 'none'}`);
	const n = initNext || prNext;
	if (n) {
		console.log(`next: ${n}`);
		console.log(`next-phase: ${PHASE_NAME[n]}${target ? ` (PR ${target})` : ''}`);
	} else {
		console.log('next: none');
		console.log(`next-phase: ${multi ? 'initiative complete or blocked' : 'flow complete'}`);
	}
	process.exit(0);
}

function finish(dir) {
	console.log('status: error');
	for (const e of errors) console.error(`flow-state: ${dir}: ${e}`);
	process.exit(1);
}

function checkFile(file) {
	if (!fs.existsSync(file) || !fs.statSync(file).isFile()) {
		console.error(`flow-state: no such file: ${file}`);
		process.exit(1);
	}
	validateArtifact(file, path.dirname(file));
	if (errors.length > 0) {
		for (const e of errors) console.error(`flow-state: ${e}`);
		process.exit(1);
	}
	console.log(`flow-state: ${file}: frontmatter valid`);
}

const blankPhase = () => ({
	state: 'pending',
	agent: '',
	input: '',
	head: '',
	summary: '',
	note: '',
});
const phases = (rows) => Object.fromEntries(rows.map((r) => [r, blankPhase()]));

function cmdInit(dir, flags) {
	rejectFlags(flags, ['slug', 'goal', 'size', 'at'], 'init');
	if (/^pr-/.test(path.basename(dir))) {
		console.error('flow-state: init: PR runbooks are created via pr --init, not init');
		process.exit(2);
	}
	if (!flags.slug) {
		const m = path.basename(dir).match(/^sk-(.+)$/);
		if (m) flags.slug = m[1];
	}
	if (!flags.slug || !SLUG_RE.test(flags.slug)) {
		console.error(`flow-state: init: invalid or missing slug '${flags.slug || ''}'`);
		process.exit(2);
	}
	if (!flags.goal) {
		console.error('flow-state: init: --goal is required');
		process.exit(2);
	}
	if (flags.size && !['light', 'full'].includes(flags.size)) {
		console.error(`flow-state: init: invalid --size '${flags.size}' (light or full)`);
		process.exit(2);
	}
	if (flags.at && !['0', '1', '2'].includes(flags.at)) {
		console.error('flow-state: init: --at must be one of 0|1|2 (review rows share artifacts)');
		process.exit(2);
	}
	if (flags.size === 'light' && flags.at && flags.at !== '0' && LIGHT_ROWS.includes(flags.at)) {
		console.error(
			`flow-state: init: --at=${flags.at} conflicts with --size=light (light skips that row)`,
		);
		process.exit(2);
	}
	fs.mkdirSync(dir, { recursive: true });
	const file = path.join(dir, 'runbook.json');
	if (fs.existsSync(file)) {
		console.error(`flow-state: init: ${file} already exists`);
		process.exit(1);
	}
	const rb = {
		'runbook-version': 2,
		slug: flags.slug,
		status: 'in-progress',
		goal: flags.goal,
		phases: phases(ROWS_SINGLE),
		divergences: [],
	};
	if (flags.size) rb.size = flags.size;
	const skip = (r, note) => {
		rb.phases[r].state = 'skipped';
		rb.phases[r].note = note;
	};
	if (flags.at && flags.at !== '0') {
		for (const r of ROWS_SINGLE.slice(0, ROWS_SINGLE.indexOf(flags.at)))
			skip(r, 'standalone entry');
		rb.divergences.push(`standalone entry at row ${flags.at}`);
	}
	if (rb.size === 'light')
		for (const r of LIGHT_ROWS) if (rb.phases[r].state === 'pending') skip(r, 'size: light');
	writeJson(file, rb);
	console.log(`init: ${file}`);
}

function flowErrors(dir, rb, overrides = {}) {
	errors.length = 0;
	validate(RUNBOOK_SCHEMA, rb, 'runbook.json');
	validateFlow(dir, rb, overrides);
	return [...errors];
}

const ROW_FLAGS = ['agent', 'input', 'head', 'summary', 'note'];
const FIELD_FLAGS = ['status', 'size', 'goal', 'active-pr'];

function cmdSet(dir, args, flags) {
	if (flags['active-pr'] !== undefined && /^pr-/.test(path.basename(dir))) {
		console.error('flow-state: set: --active-pr is not valid on a PR runbook');
		process.exit(2);
	}
	const file = path.join(dir, 'runbook.json');
	const rb = loadRunbook(dir, 'runbook');
	if (!rb) {
		for (const e of errors) console.error(`flow-state: ${dir}: ${e}`);
		process.exit(1);
	}
	const prior = flowErrors(dir, structuredClone(rb));
	if (typeOf(rb.phases) !== 'object') rb.phases = {};
	if (!Array.isArray(rb.divergences)) rb.divergences = [];
	if ('prs' in rb && rb['active-pr'] === undefined) rb['active-pr'] = 'none';
	const [row, state] = args;
	if (args.length > 2) usage();
	if (row !== undefined) {
		rejectFlags(flags, ROW_FLAGS, 'set <row>');
		if (state === undefined || !STATES.includes(state)) {
			console.error(`flow-state: set: row state must be one of ${STATES.join('|')}`);
			process.exit(2);
		}
		const expected = 'prs' in rb || 'active-pr' in rb ? ROWS_INITIATIVE : ROWS_SINGLE;
		if (!expected.includes(row)) {
			console.error(
				`flow-state: set: row '${row}' is not valid here (expected ${expected.join(' ')})`,
			);
			process.exit(2);
		}
		if (typeOf(rb.phases[row]) !== 'object') rb.phases[row] = blankPhase();
		const ph = rb.phases[row];
		if (['done', 'skipped', 'diverged', 'in-progress'].includes(state))
			for (const r of expected.slice(0, expected.indexOf(row)))
				if (
					typeOf(rb.phases[r]) === 'object' &&
					rb.phases[r].reopened &&
					!['done', 'skipped', 'diverged'].includes(rb.phases[r].state)
				) {
					console.error(
						`flow-state: set: cannot set row ${row} ${state} while reopened row ${r} is ${rb.phases[r].state}`,
					);
					process.exit(2);
				}
		if (['skipped', 'diverged', 'blocked'].includes(state)) {
			const effNote = flags.note !== undefined ? flags.note : ph.note;
			if (!effNote) {
				console.error(`flow-state: set: '${state}' requires --note=<reason>`);
				process.exit(2);
			}
		}
		if (state === 'pending' && ['done', 'skipped', 'diverged'].includes(ph.state))
			ph.reopened = true;
		ph.state = state;
		for (const k of ROW_FLAGS) if (flags[k] !== undefined) ph[k] = flags[k];
		if (flags.note && ['skipped', 'diverged'].includes(state))
			rb.divergences.push(`row ${row}: ${flags.note}`);
	} else {
		rejectFlags(flags, FIELD_FLAGS, 'set');
		if (flags.status && !FLOW_STATUSES.includes(flags.status)) {
			console.error(`flow-state: set: --status must be one of ${FLOW_STATUSES.join('|')}`);
			process.exit(2);
		}
		if (flags.size && !RUNBOOK_SCHEMA.properties.size.enum.includes(flags.size)) {
			console.error('flow-state: set: --size must be light or full');
			process.exit(2);
		}
		const priorSize = rb.size || 'full';
		let updated = false;
		for (const k of FIELD_FLAGS) {
			if (flags[k] === undefined) continue;
			rb[k] = flags[k];
			updated = true;
		}
		if (!updated) {
			console.error('flow-state: set: nothing to update');
			process.exit(2);
		}
		if (flags.size && flags.size !== priorSize) {
			if (flags.size === 'light') {
				for (const r of LIGHT_ROWS) {
					const ph = rb.phases[r];
					const st = typeOf(ph) === 'object' ? ph.state : ph;
					if (st === 'pending') {
						if (typeOf(ph) === 'object') {
							ph.state = 'skipped';
							ph.note ||= 'size: light';
						} else
							rb.phases[r] = {
								...blankPhase(),
								state: 'skipped',
								note: 'size: light',
							};
						rb.divergences.push(`row ${r}: skipped by size: light`);
					} else if (st !== 'skipped') {
						console.error(
							`flow-state: set: cannot switch to light: row ${r} is ${st ?? 'missing'}`,
						);
						process.exit(1);
					}
				}
			} else {
				for (const r of LIGHT_ROWS)
					if (rb.phases[r]?.state === 'skipped') {
						rb.phases[r] = blankPhase();
						rb.phases[r].reopened = true;
					}
			}
		}
	}
	const after = flowErrors(dir, rb);
	const added = after.filter((e) => !prior.includes(e));
	if (added.length > 0) {
		for (const e of added) console.error(`flow-state: ${dir}: ${e}`);
		console.error('flow-state: refusing to write invalid state');
		process.exit(1);
	}
	writeJson(file, rb);
	if (row !== undefined) console.log(`set row ${row} ${state}`);
	else
		for (const k of FIELD_FLAGS)
			if (flags[k] !== undefined) console.log(`set ${k} ${flags[k]}`);
	for (const e of after) console.error(`flow-state: ${dir}: warning, still invalid: ${e}`);
}

function cmdPr(dir, slug, flags) {
	if (/^pr-/.test(path.basename(dir))) {
		console.error('flow-state: pr: a PR runbook cannot hold PRs');
		process.exit(2);
	}
	rejectFlags(
		flags,
		['repo', 'deps', 'state', 'branch', 'base-sha', 'head', 'notes', 'order', 'init'],
		'pr',
	);
	const file = path.join(dir, 'runbook.json');
	const rb = loadRunbook(dir, 'runbook');
	if (!rb) {
		for (const e of errors) console.error(`flow-state: ${dir}: ${e}`);
		process.exit(1);
	}
	const prior = flowErrors(dir, structuredClone(rb));
	if (typeOf(rb.phases) !== 'object') rb.phases = {};
	if (!Array.isArray(rb.divergences)) rb.divergences = [];
	if (!SLUG_RE.test(slug) || slug === 'none') {
		console.error(`flow-state: pr: invalid slug '${slug}'`);
		process.exit(2);
	}
	if (flags.state && !PR_STATES.includes(flags.state)) {
		console.error(`flow-state: pr: --state must be one of ${PR_STATES.join('|')}`);
		process.exit(2);
	}
	if (flags.order !== undefined && !/^[1-9][0-9]*$/.test(flags.order)) {
		console.error('flow-state: pr: --order must be a positive integer');
		process.exit(2);
	}
	if (!('prs' in rb) && !('active-pr' in rb)) {
		for (const r of Object.keys(rb.phases))
			if (!ROWS_INITIATIVE.includes(r)) {
				const st = rb.phases[r]?.state;
				if (st !== 'pending' && st !== 'skipped') {
					console.error(
						`flow-state: pr: cannot convert: row ${r} is ${st} (only pending/skipped rows may be dropped)`,
					);
					process.exit(1);
				}
				delete rb.phases[r];
			}
		rb['active-pr'] = 'none';
	}
	if (typeOf(rb.prs) !== 'object') rb.prs = {};
	if (rb['active-pr'] === undefined) rb['active-pr'] = 'none';
	const existing =
		Object.hasOwn(rb.prs, slug) && typeOf(rb.prs[slug]) === 'object' ? rb.prs[slug] : undefined;
	const effNotes = flags.notes !== undefined ? flags.notes : existing?.notes;
	if (flags.state === 'blocked' && !effNotes) {
		console.error('flow-state: pr: --state=blocked requires --notes=<reason>');
		process.exit(2);
	}
	if (flags.state === 'done' && !effNotes) {
		console.error('flow-state: pr: --state=done requires --notes=<pr-url>');
		process.exit(2);
	}
	if (!existing && !flags.repo) {
		console.error(`flow-state: pr: --repo is required to add PR ${slug}`);
		process.exit(2);
	}
	const order = existing?.order ?? Math.max(0, ...Object.values(rb.prs).map(orderOf)) + 1;
	const pr = existing || {
		order,
		repo: flags.repo,
		deps: [],
		state: 'pending',
		branch: '',
		'base-sha': '',
		head: '',
		notes: '',
	};
	for (const k of ['repo', 'state', 'branch', 'base-sha', 'head', 'notes'])
		if (flags[k] !== undefined) pr[k] = flags[k];
	if (flags.order !== undefined) pr.order = parseInt(flags.order, 10);
	if (flags.deps !== undefined) pr.deps = flags.deps === '' ? [] : flags.deps.split(',');
	const prFile = path.join(dir, `pr-${slug}`, 'runbook.json');
	if (flags.state === 'done' && !fs.existsSync(prFile)) {
		console.error(
			`flow-state: pr: cannot mark ${slug} done before its runbook exists (scaffold via --init first)`,
		);
		process.exit(2);
	}
	const prb =
		flags.init && !fs.existsSync(prFile)
			? {
					'runbook-version': 2,
					slug,
					status: 'in-progress',
					size: 'full',
					goal: rb.goal,
					phases: phases(ROWS_SINGLE),
					divergences: [],
				}
			: null;
	if (prb)
		for (const r of ['0', '1', '1r']) {
			prb.phases[r].state = 'skipped';
			prb.phases[r].note = 'initiative root';
		}
	if (
		existing &&
		!prb &&
		!['repo', 'deps', 'state', 'branch', 'base-sha', 'head', 'notes', 'order'].some(
			(k) => flags[k] !== undefined,
		)
	) {
		console.error(`flow-state: pr: nothing to update for ${slug}`);
		process.exit(2);
	}
	rb.prs[slug] = pr;
	if (flags.state === 'in-progress') rb['active-pr'] = slug;
	else if (flags.state && rb['active-pr'] === slug) rb['active-pr'] = 'none';
	const after = flowErrors(dir, rb, prb ? { [slug]: prb } : {});
	const added = after.filter(
		(e) =>
			!prior.includes(e) &&
			!/^initiative: (masterplan )?PR \S+ has no pr-\S+(\/runbook\.json|\/ directory)$/.test(
				e,
			),
	);
	if (added.length > 0) {
		for (const e of added) console.error(`flow-state: ${dir}: ${e}`);
		console.error('flow-state: refusing to write invalid state');
		process.exit(1);
	}
	if (prb) {
		const pd = path.dirname(prFile);
		if (fs.existsSync(pd) && !isDir(pd)) {
			console.error(`flow-state: pr: ${pd} exists and is not a directory`);
			process.exit(1);
		}
		fs.mkdirSync(pd, { recursive: true });
		writeJson(prFile, prb);
	}
	writeJson(file, rb);
	console.log(`pr ${slug}: ${JSON.stringify(pr)}`);
	if (prb) console.log(`init: ${prFile}`);
	for (const e of after) console.error(`flow-state: ${dir}: warning, still invalid: ${e}`);
}

try {
	initSchemas();
	const [, , cmd, ...rest] = process.argv;
	const flags = Object.create(null);
	const pos = [];
	for (const a of rest) {
		if (a === '--init') flags.init = true;
		else if (a.startsWith('--init=') || a === '--multi' || a.startsWith('--multi=')) usage();
		else if (a.startsWith('--')) {
			const i = a.indexOf('=');
			if (i === -1) usage();
			flags[a.slice(2, i)] = a.slice(i + 1);
		} else pos.push(a);
	}
	if (cmd === 'check') {
		if (pos.length !== 1 || Object.keys(flags).length > 0) usage();
		const target = pos[0];
		if (fs.existsSync(target) && fs.statSync(target).isFile()) checkFile(target);
		else checkFlow(target);
	} else if (cmd === 'init') {
		if (pos.length !== 1) usage();
		cmdInit(pos[0], flags);
	} else if (cmd === 'set') {
		if (pos.length < 1) usage();
		cmdSet(pos[0], pos.slice(1), flags);
	} else if (cmd === 'pr') {
		if (pos.length !== 2) usage();
		cmdPr(pos[0], pos[1], flags);
	} else usage();
} catch (e) {
	console.error(`flow-state: ${e.message}`);
	process.exit(1);
}
