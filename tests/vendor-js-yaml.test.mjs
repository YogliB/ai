/** vendor-js-yaml tests: every shipped skill carries the same js-yaml build. */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { REPO_ROOT, run } from './helpers.mjs';

test('all vendor copies match node_modules/js-yaml', () => {
	const r = run(REPO_ROOT + '/scripts/vendor-js-yaml.mjs', ['--check'], { cwd: REPO_ROOT });
	assert.equal(r.status, 0, `${r.stderr}; run node scripts/vendor-js-yaml.mjs`);
});
