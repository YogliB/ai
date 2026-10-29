#!/usr/bin/env node
/**
 * lint-plan: validate a plan's structure against the snail-planning YAML
 * templates: required keys present and in template order, values non-empty,
 * no template placeholders left, files right after goal, TODO depth at most
 * 2, complexity_check.decision explicitly proceed or split.
 * See docs/ARCHITECTURE.md#gates.
 *
 * Usage: lint-plan.mjs <plan-file> [--masterplan] [--allow-draft]
 */
import { existsSync, readFileSync } from 'node:fs';
import yaml from './vendor/js-yaml.mjs';
import { requireNode24 } from './node-guard.mjs';

requireNode24('lint-plan');

const PLAN_KEYS = [
	'goal',
	'files',
	'context',
	'scope',
	'risks',
	'dependencies',
	'priority',
	'logging_observability',
	'branch_setup',
	'implementation_todos',
	'delivery',
	'docs',
	'testing',
	'verification',
	'acceptance',
	'fallback_plan',
	'references',
	'complexity_check',
];
const MASTER_KEYS = [
	'files',
	'context',
	'implementation_status',
	'risk_mitigation',
	'deployment_strategy',
	'monitoring_observability',
	'verification',
	'rollback',
	'delivery',
	'success_criteria',
	'references',
	'notes_assumptions',
];
const DRAFT_OK = new Set(['branch_setup', 'delivery', 'complexity_check']);

function usage() {
	console.error('usage: lint-plan.mjs <plan-file> [--masterplan] [--allow-draft]');
	process.exit(2);
}

const argv = process.argv.slice(2);
if (argv.length < 1) usage();
const plan = argv[0];
let mode = 'plan';
let allowDraft = false;
for (const a of argv.slice(1)) {
	if (a === '--masterplan') mode = 'masterplan';
	else if (a === '--allow-draft') allowDraft = true;
	else usage();
}

if (!existsSync(plan)) {
	console.error(`lint-plan: no such file: ${plan}`);
	process.exit(1);
}

let failed = false;
/** Report a validation problem. */
function err(msg) {
	console.error(`lint-plan: ${plan}: ${msg}`);
	failed = true;
}

let doc;
try {
	doc = yaml.load(readFileSync(plan, 'utf8'), { json: false });
} catch (e) {
	err(`not valid YAML: ${e.message.split('\n')[0]}`);
	process.exit(1);
}
if (doc === null || typeof doc !== 'object' || Array.isArray(doc)) {
	err('plan must be a YAML mapping');
	process.exit(1);
}

const keys = Object.keys(doc);
const required = mode === 'masterplan' ? MASTER_KEYS : PLAN_KEYS;

/** A value counts as filled when it is a non-blank string, a non-empty
 *  list, a non-empty mapping, or a number/boolean. */
function filled(v) {
	if (v === undefined || v === null) return false;
	if (typeof v === 'string') return v.trim() !== '';
	if (Array.isArray(v)) return v.length > 0;
	if (typeof v === 'object') return Object.keys(v).length > 0;
	return true;
}

/** Any string value still carrying a template placeholder. */
function hasPlaceholder(v) {
	if (typeof v === 'string') return v.includes('{{') || v.includes('[Proceed / Split]');
	if (Array.isArray(v)) return v.some(hasPlaceholder);
	if (v && typeof v === 'object') return Object.values(v).some(hasPlaceholder);
	return false;
}

let prev = -1;
let prevName = '';
for (const k of required) {
	const idx = keys.indexOf(k);
	if (idx === -1) {
		if (allowDraft && DRAFT_OK.has(k)) continue;
		err(`missing required key: ${k}`);
		continue;
	}
	if (idx < prev) err(`key out of order: ${k} must come after ${prevName}`);
	prev = Math.max(prev, idx);
	prevName = k;
	if (!filled(doc[k])) err(`key is empty: ${k}`);
	if (hasPlaceholder(doc[k])) err(`key still has a template placeholder: ${k}`);
}

if (mode === 'plan') {
	const goalIdx = keys.indexOf('goal');
	if (goalIdx !== -1) {
		const next = keys.slice(goalIdx + 1).find((k) => k !== 'schema');
		if (next !== 'files') err(`files must come right after goal, found ${next ?? '(none)'}`);
	}
	const todos = doc.implementation_todos;
	if (filled(todos)) {
		if (!Array.isArray(todos)) {
			err('implementation_todos must be a list');
		} else {
			/** Deepest nesting of subtasks under the TODO list. */
			const depth = (items) =>
				items.reduce((d, it) => {
					if (!it || typeof it !== 'object') return Math.max(d, 1);
					if (it.subtasks === undefined) return Math.max(d, 1);
					if (!Array.isArray(it.subtasks)) {
						err('implementation_todos subtasks must be a list');
						return d;
					}
					return Math.max(d, 1 + (it.subtasks.length ? depth(it.subtasks) : 0));
				}, 0);
			const d = depth(todos);
			if (d > 2) err('implementation_todos nests deeper than 2 levels');
			console.error(`lint-plan: ${plan}: ${todos.length} top-level TODOs`);
			const all = (items) =>
				items.reduce(
					(n, it) =>
						n +
						1 +
						(it && typeof it === 'object' && Array.isArray(it.subtasks)
							? all(it.subtasks)
							: 0),
					0,
				);
			if (all(todos) > 30)
				console.error(
					`lint-plan: ${plan}: info: more than 30 TODOs, snail-planning's split threshold`,
				);
		}
	}
	const cc = doc.complexity_check;
	if (filled(cc)) {
		const decision = cc && typeof cc === 'object' ? String(cc.decision ?? '').trim() : '';
		if (decision !== 'proceed' && decision !== 'split') {
			err("complexity_check.decision must be 'proceed' or 'split'");
		}
	}
}

if (!failed) console.log(`lint-plan: ${plan}: passed`);
process.exit(failed ? 1 : 0);
