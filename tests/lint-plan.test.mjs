/** Plan lint tests: required keys, order, depth, decision, placeholders. */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import yaml from '../skills/snail-planning/scripts/vendor/js-yaml.mjs';
import { REPO_ROOT, tmpdir_, run } from './helpers.mjs';

const LINT = join(REPO_ROOT, 'skills/snail-planning/scripts/lint-plan.mjs');
const TEMPLATE = join(REPO_ROOT, 'skills/snail-planning/templates/plan.yaml');
const MASTER = join(REPO_ROOT, 'skills/snail-planning/templates/masterplan.yaml');

/** A plan object with every required key filled. */
function goodPlan() {
	return {
		goal: 'Ship the demo',
		files: ['a.js', 'b.js'],
		context: 'everything needed inline',
		scope: { in: ['x'], out: ['y'] },
		risks: [{ risk: 'r1', mitigation: 'm1' }],
		dependencies: ['d1'],
		priority: 'High',
		logging_observability: ['log 1'],
		branch_setup: 'feature/demo',
		implementation_todos: [
			{
				action: 'Step 1',
				verify: 'v1',
				subtasks: [
					{ action: 'Task 1.1', verify: 'v' },
					{ action: 'Task 1.2', verify: 'v' },
				],
			},
			{ action: 'Step 2', verify: 'v2', subtasks: [{ action: 'Task 2.1', verify: 'v' }] },
		],
		delivery: 'commit and push on the branch',
		docs: [{ document: 'README', path: 'README.md' }],
		testing: ['unit tests'],
		verification: ['run it end to end'],
		acceptance: ['it works'],
		fallback_plan: 'revert',
		references: 'None',
		complexity_check: { todos: 5, depth: 2, cross_deps: 0, high_risks: 0, decision: 'proceed' },
	};
}

/** Write a plan fixture and return its path. */
function fixture(t, name, doc) {
	const p = join(tmpdir_(t), name);
	writeFileSync(p, typeof doc === 'string' ? doc : yaml.dump(doc, { lineWidth: -1 }));
	return p;
}

test('a filled plan passes and echoes the TODO count', (t) => {
	const p = fixture(t, 'good.yaml', goodPlan());
	const r = run(LINT, [p]);
	assert.equal(r.status, 0, r.stderr);
	assert.match(r.stderr, /2 top-level TODOs/);
});

test('the shipped templates are valid YAML and the lint parses them', (t) => {
	for (const tpl of [TEMPLATE, MASTER]) {
		assert.ok(yaml.load(readFileSync(tpl, 'utf8')), `${tpl} does not parse`);
	}
	const r = run(LINT, [TEMPLATE]);
	assert.notEqual(r.status, 0, 'the placeholder template passes lint');
	assert.match(r.stderr, /template placeholder/);
});

test('the masterplan template passes --masterplan --allow-draft once placeholders are filled', (t) => {
	const doc = yaml.load(readFileSync(MASTER, 'utf8'));
	const fill = (v) => {
		if (typeof v === 'string') return v.replace(/\{\{(?:[^{}]|\{[^{}]*\})*\}\}/g, 'x');
		if (Array.isArray(v)) return v.map(fill);
		if (v && typeof v === 'object')
			return Object.fromEntries(Object.entries(v).map(([k, val]) => [k, fill(val)]));
		return v;
	};
	const filled = fill(doc);
	const p = fixture(t, 'master.yaml', filled);
	assert.equal(
		run(LINT, [p, '--masterplan', '--allow-draft']).status,
		0,
		'a filled masterplan fails with --allow-draft',
	);
	assert.equal(run(LINT, [p, '--masterplan']).status, 0, 'a filled masterplan fails');
	delete filled.delivery;
	delete filled.prs_detail;
	const draft = fixture(t, 'master-draft.yaml', filled);
	assert.notEqual(
		run(LINT, [draft, '--masterplan']).status,
		0,
		'a draft masterplan passes without --allow-draft',
	);
	assert.equal(
		run(LINT, [draft, '--masterplan', '--allow-draft']).status,
		0,
		'--allow-draft rejects a draft masterplan',
	);
});

test('a missing key is named', (t) => {
	const doc = goodPlan();
	delete doc.risks;
	const r = run(LINT, [fixture(t, 'no-risks.yaml', doc)]);
	assert.notEqual(r.status, 0);
	assert.match(r.stderr, /missing required key: risks/);
});

test('an empty value is reported', (t) => {
	const doc = goodPlan();
	doc.context = '  ';
	const r = run(LINT, [fixture(t, 'empty.yaml', doc)]);
	assert.notEqual(r.status, 0);
	assert.match(r.stderr, /key is empty: context/);
});

test('a key out of order is reported', (t) => {
	const doc = goodPlan();
	const reordered = {};
	for (const k of Object.keys(doc)) {
		if (k === 'scope') continue;
		reordered[k] = doc[k];
		if (k === 'risks') reordered.scope = doc.scope;
	}
	const r = run(LINT, [fixture(t, 'reorder.yaml', reordered)]);
	assert.notEqual(r.status, 0);
	assert.match(r.stderr, /out of order/);
});

test('files must come right after goal', (t) => {
	const doc = goodPlan();
	const swapped = { goal: doc.goal, context: doc.context, files: doc.files };
	for (const k of Object.keys(doc)) if (!(k in swapped)) swapped[k] = doc[k];
	const r = run(LINT, [fixture(t, 'swap.yaml', swapped)]);
	assert.notEqual(r.status, 0);
	assert.match(r.stderr, /files must come right after goal/);
});

test('TODO nesting deeper than 2 levels is reported', (t) => {
	const doc = goodPlan();
	doc.implementation_todos[0].subtasks[0].subtasks = [{ action: 'too deep', verify: 'v' }];
	const r = run(LINT, [fixture(t, 'deep.yaml', doc)]);
	assert.notEqual(r.status, 0);
	assert.match(r.stderr, /deeper than 2 levels/);
});

test('plain-string leaf subtasks count toward depth', (t) => {
	const doc = goodPlan();
	doc.implementation_todos[0].subtasks[0].subtasks = ['plain string leaf'];
	const r = run(LINT, [fixture(t, 'strleaf.yaml', doc)]);
	assert.notEqual(r.status, 0, 'a string leaf at level 3 silently passes');
	assert.match(r.stderr, /deeper than 2 levels/);
});

test('a plain-string subtask at level 2 passes', (t) => {
	const doc = goodPlan();
	doc.implementation_todos[0].subtasks = ['plain string leaf'];
	const r = run(LINT, [fixture(t, 'strleaf2.yaml', doc)]);
	assert.equal(r.status, 0, r.stderr);
});

test('a non-list subtasks value is reported', (t) => {
	const doc = goodPlan();
	doc.implementation_todos[0].subtasks = { subtasks: { action: 'hidden depth' } };
	const r = run(LINT, [fixture(t, 'badsub.yaml', doc)]);
	assert.notEqual(r.status, 0, 'a mapping subtasks silently passes');
	assert.match(r.stderr, /subtasks must be a list/);
});

test('subtasks on non-TODO keys do not count for depth', (t) => {
	const doc = goodPlan();
	doc.acceptance = [{ subtasks: [{ subtasks: ['buried'] }] }];
	const r = run(LINT, [fixture(t, 'scoped.yaml', doc)]);
	assert.equal(r.status, 0, r.stderr);
});

test('decision must be explicitly proceed or split', (t) => {
	for (const [decision, ok] of [
		['proceed', true],
		['split', true],
		['ProceedLater', false],
		['proceed / split', false],
		['{{proceed / split}}', false],
		['', false],
	]) {
		const doc = goodPlan();
		doc.complexity_check.decision = decision;
		const r = run(LINT, [
			fixture(t, `dec-${decision.replace(/[^a-z]/g, '') || 'empty'}.yaml`, doc),
		]);
		assert.equal(r.status === 0, ok, `decision '${decision}': ${r.stderr}`);
	}
});

test('--allow-draft permits a draft without the delivery keys', (t) => {
	const doc = goodPlan();
	delete doc.branch_setup;
	delete doc.delivery;
	delete doc.complexity_check;
	const p = fixture(t, 'draft.yaml', doc);
	assert.notEqual(run(LINT, [p]).status, 0, 'a draft passes without --allow-draft');
	assert.equal(run(LINT, [p, '--allow-draft']).status, 0, '--allow-draft rejects a valid draft');
});

test('duplicate keys are rejected by the parser', (t) => {
	const text = yaml.dump(goodPlan(), { lineWidth: -1 }) + '\ngoal: duplicate\n';
	const r = run(LINT, [fixture(t, 'dup.yaml', text)]);
	assert.notEqual(r.status, 0);
	assert.match(r.stderr, /not valid YAML|duplicated mapping key/);
});

test('invalid YAML and non-mapping docs are rejected with exit 1', (t) => {
	assert.equal(run(LINT, [fixture(t, 'bad.yaml', 'goal: [unclosed')]).status, 1);
	assert.equal(run(LINT, [fixture(t, 'list.yaml', '- a\n- b\n')]).status, 1);
});

test('more than 30 TODOs prints the split-threshold info', (t) => {
	const doc = goodPlan();
	doc.implementation_todos = Array.from({ length: 31 }, (_, i) => ({
		action: `Step ${i}`,
		verify: 'v',
	}));
	const r = run(LINT, [fixture(t, 'many.yaml', doc)]);
	assert.equal(r.status, 0, r.stderr);
	assert.match(r.stderr, /more than 30 TODOs/);
});

test('bad usage exits 2 and a missing file exits 1', (t) => {
	assert.equal(run(LINT, []).status, 2);
	assert.equal(run(LINT, [join(tmpdir_(t), 'missing.yaml')]).status, 1);
});
