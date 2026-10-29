#!/usr/bin/env node
/**
 * vendor-js-yaml: copy the single-file js-yaml ESM build from
 * node_modules/js-yaml (a devDependency) into each skill's scripts/vendor/
 * directory, so every installed skill is self-contained and needs no
 * consumer-side npm install or network access.
 *
 * Usage: node scripts/vendor-js-yaml.mjs [--check]
 */
import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { requireNode24 } from './node-guard.mjs';

requireNode24('vendor-js-yaml');

const root = execFileSync('git', ['rev-parse', '--show-toplevel'], { encoding: 'utf8' }).trim();
const dist = join(root, 'node_modules', 'js-yaml', 'dist', 'js-yaml.mjs');
const check = process.argv[2] === '--check';

if (!existsSync(dist)) {
	console.error('vendor-js-yaml: node_modules/js-yaml not found; run npm install first');
	process.exit(1);
}
const src = readFileSync(dist);

let status = 0;
for (const d of readdirSync(join(root, 'skills'))) {
	const scriptsDir = join(root, 'skills', d, 'scripts');
	if (!d.startsWith('snail-') || !existsSync(scriptsDir)) continue;
	const target = join(scriptsDir, 'vendor', 'js-yaml.mjs');
	if (check) {
		if (!existsSync(target) || readFileSync(target).compare(src) !== 0) {
			console.error(
				`vendor-js-yaml: skills/${d}/scripts/vendor/js-yaml.mjs is out of date; run node scripts/vendor-js-yaml.mjs`,
			);
			status = 1;
		}
	} else {
		mkdirSync(join(scriptsDir, 'vendor'), { recursive: true });
		copyFileSync(dist, target);
		console.log(`vendor-js-yaml: wrote skills/${d}/scripts/vendor/js-yaml.mjs`);
	}
}
if (check && status === 0) console.log('vendor-js-yaml: all vendor copies are in sync');
process.exit(status);
