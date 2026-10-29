/** install-claude-rules tests: rules land frontmatter-free in ~/.claude/snail and stay linked. */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { REPO_ROOT, tmpdir_, run } from './helpers.mjs';

const SCRIPT = join(REPO_ROOT, 'scripts/install-claude-rules.mjs');

test('install copies rules, strips frontmatter, links, and prunes stale links', (t) => {
	const home = join(tmpdir_(t), 'home');
	const dest = join(home, '.claude', 'snail');
	const memory = join(home, '.claude', 'CLAUDE.md');
	mkdirSync(dest, { recursive: true });
	writeFileSync(join(dest, 'stale.md'), 'old rule\n');
	writeFileSync(memory, '# my notes\n  @snail/stale.md\n@snail/other.md\n');

	const r = run(SCRIPT, [], { env: { ...process.env, HOME: home } });
	assert.equal(r.status, 0, r.stderr);

	const snail = readFileSync(join(dest, 'snail.md'), 'utf8');
	assert.ok(!snail.startsWith('---'), 'frontmatter survived');
	assert.throws(() => readFileSync(join(dest, 'stale.md')), 'stale rule file kept');

	const lines = readFileSync(memory, 'utf8').split('\n');
	assert.ok(lines.includes('# my notes'), 'user content lost');
	assert.ok(!lines.some((l) => l.includes('stale.md')), 'stale link kept');
	for (const f of ['no-comments.md', 'snail.md']) {
		assert.ok(lines.includes(`@snail/${f}`), `${f} not linked`);
	}
});
