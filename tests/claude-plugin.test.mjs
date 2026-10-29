/**
 * Claude Code plugin install test. Needs network (installs claude-code from
 * npm); runs only when CLAUDE_PLUGIN_TEST=1, e.g. in the dedicated CI job.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { REPO_ROOT, tmpdir_ } from './helpers.mjs';

const VERSION = process.env.CLAUDE_CODE_VERSION || '2.1.304';

test(
	'snail installs as a Claude Code plugin with 12 skills',
	{
		skip:
			process.env.CLAUDE_PLUGIN_TEST !== '1' &&
			'set CLAUDE_PLUGIN_TEST=1 to run (needs network)',
	},
	(t) => {
		const tmp = tmpdir_(t, 'snail-claude-');
		const npmi = spawnSync(
			'npm',
			[
				'install',
				'-g',
				'--prefix',
				join(tmp, 'npm'),
				'--no-fund',
				'--no-audit',
				`@anthropic-ai/claude-code@${VERSION}`,
			],
			{ encoding: 'utf8', timeout: 600000 },
		);
		assert.equal(npmi.status, 0, `claude-code ${VERSION} install failed:\n${npmi.stderr}`);
		const claude = join(tmp, 'npm/bin/claude');
		const home = join(tmp, 'home');
		mkdirSync(home);
		const env = { ...process.env, HOME: home };
		delete env.CLAUDE_CONFIG_DIR;
		const run_ = (args) => spawnSync(claude, args, { encoding: 'utf8', env, timeout: 300000 });
		assert.equal(
			run_(['plugin', 'marketplace', 'add', REPO_ROOT]).status,
			0,
			'marketplace add failed',
		);
		assert.equal(run_(['plugin', 'install', 'snail@snail']).status, 0, 'plugin install failed');
		const details = run_(['plugin', 'details', 'snail@snail']);
		assert.equal(details.status, 0, 'plugin details failed');
		assert.match(details.stdout, /Skills \(12\)/, `expected 12 skills:\n${details.stdout}`);
	},
);
