/** gen-skills-index tests: the skills list in rules/snail.md tracks skills/. */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { REPO_ROOT, tmpdir_, run, gitInit } from './helpers.mjs';

const GEN = join(REPO_ROOT, 'scripts/gen-skills-index.mjs');

function setup(t) {
	const tmp = tmpdir_(t);
	gitInit(tmp);
	mkdirSync(join(tmp, 'skills/snail-a'), { recursive: true });
	mkdirSync(join(tmp, 'skills/snail-b'), { recursive: true });
	mkdirSync(join(tmp, 'rules'));
	writeFileSync(
		join(tmp, 'skills/snail-a/SKILL.md'),
		'---\nname: snail-a\ndescription: Does A. Use when A.\n---\n',
	);
	writeFileSync(
		join(tmp, 'skills/snail-b/SKILL.md'),
		'---\nname: snail-b\ndescription: Does B.\n---\n',
	);
	writeFileSync(
		join(tmp, 'rules/snail.md'),
		'head\n\n<!-- skills:start -->\nstale\n<!-- skills:end -->\n\ntail\n',
	);
	return tmp;
}

test('generate then --check agrees; stale, added and removed skills are caught', (t) => {
	const tmp = setup(t);
	assert.notEqual(
		run(GEN, ['--check'], { cwd: tmp }).status,
		0,
		'--check passes on a stale list',
	);
	assert.equal(run(GEN, [], { cwd: tmp }).status, 0);
	assert.equal(
		run(GEN, ['--check'], { cwd: tmp }).status,
		0,
		'--check fails right after generating',
	);
	const out = readFileSync(join(tmp, 'rules/snail.md'), 'utf8');
	assert.match(out, /`snail-a` — Does A/);
	assert.match(out, /`snail-b` — Does B/);
	assert.ok(out.split('\n').includes('head'), 'text before the markers changed');
	assert.ok(out.split('\n').includes('tail'), 'text after the markers changed');

	mkdirSync(join(tmp, 'skills/snail-c'));
	writeFileSync(
		join(tmp, 'skills/snail-c/SKILL.md'),
		'---\nname: snail-c\ndescription: Does C.\n---\n',
	);
	assert.notEqual(run(GEN, ['--check'], { cwd: tmp }).status, 0, '--check misses a new skill');

	run(GEN, [], { cwd: tmp });
	rmSync(join(tmp, 'skills/snail-b'), { recursive: true });
	assert.notEqual(
		run(GEN, ['--check'], { cwd: tmp }).status,
		0,
		'--check misses a removed skill',
	);
});

test('missing or reversed markers are reported without touching content', (t) => {
	const tmp = setup(t);
	writeFileSync(join(tmp, 'rules/snail.md'), 'no markers\n');
	assert.notEqual(run(GEN, [], { cwd: tmp }).status, 0, 'missing markers are not reported');
	writeFileSync(
		join(tmp, 'rules/snail.md'),
		'<!-- skills:end -->\nmiddle\n<!-- skills:start -->\n',
	);
	assert.notEqual(run(GEN, [], { cwd: tmp }).status, 0, 'reversed markers are not reported');
	assert.ok(
		readFileSync(join(tmp, 'rules/snail.md'), 'utf8').split('\n').includes('middle'),
		'reversed markers deleted content',
	);
});

test('the real repo list is in sync', () => {
	assert.equal(
		run(GEN, ['--check'], { cwd: REPO_ROOT }).status,
		0,
		'rules/snail.md is out of date; run node scripts/gen-skills-index.mjs',
	);
});
