/**
 * Shared helpers for the snail test suite: temp dirs, git repos and running
 * the repo's scripts with the same Node that runs the tests.
 */
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

export const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

/** A fresh temp dir; register cleanup with t.after. */
export function tmpdir_(t, prefix = 'snail-test-') {
	const d = mkdtempSync(join(tmpdir(), prefix));
	t.after(() => rmSync(d, { recursive: true, force: true }));
	return d;
}

/** Run a script with Node, returning {status, stdout, stderr}. */
export function run(script, args, opts = {}) {
	const r = spawnSync(process.execPath, [script, ...args], { encoding: 'utf8', ...opts });
	return { status: r.status, stdout: r.stdout ?? '', stderr: r.stderr ?? '' };
}

/** git in dir; dies the test process on failure. */
export function git(dir, args) {
	const r = spawnSync('git', ['-C', dir, ...args], { encoding: 'utf8' });
	if (r.status !== 0) throw new Error(`git ${args.join(' ')} failed: ${r.stderr}`);
	return r.stdout.trim();
}

/** Init a git repo with a committed state. */
export function gitInit(dir) {
	git(dir, ['init', '-q', '.']);
	git(dir, ['config', 'user.email', 'test@test']);
	git(dir, ['config', 'user.name', 'test']);
}
