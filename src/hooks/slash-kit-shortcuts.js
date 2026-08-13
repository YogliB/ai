#!/usr/bin/env node
// slash-kit workflow shortcuts for Claude Code.
// Each shortcut loads the matching sk-* skill from .agents/skills/ so the
// skill file is the source of truth for the behavior.

const fs = require('fs');
const path = require('path');
const readline = require('readline');

const SKILL_SHORTCUTS = {
	'/explore': 'sk-explore',
	'/alternatives': 'sk-alternatives',
	'/plan': 'sk-planning',
	'/review': 'sk-review-and-fix',
	'/pr': 'sk-pr',
	'/flow': 'sk-flow',
};

async function main() {
	const rl = readline.createInterface({
		input: process.stdin,
		output: process.stdout,
		terminal: false,
	});

	const lines = [];
	for await (const line of rl) lines.push(line);

	let data = {};
	try {
		data = JSON.parse(lines.join('\n'));
	} catch {
		process.exit(0);
	}

	const prompt = String(data.prompt || data.userPrompt || '').trim();
	if (!prompt) process.exit(0);

	const firstWord = prompt.split(/\s+/)[0];
	const skill = SKILL_SHORTCUTS[firstWord];
	if (!skill) process.exit(0);

	const skillFile = path.join(__dirname, '..', '..', '.agents', 'skills', skill, 'SKILL.md');
	let content = '';
	try {
		content = fs.readFileSync(skillFile, 'utf8');
	} catch {
		process.stdout.write(
			JSON.stringify({
				hookSpecificOutput: `[slash-kit] Invoke the ${skill} skill. The skill file at ${skillFile} could not be read.`,
			}),
		);
		process.exit(0);
	}

	// Strip YAML frontmatter.
	if (content.startsWith('---\n')) {
		const end = content.indexOf('\n---\n');
		if (end !== -1) {
			content = content.slice(end + 5);
		}
	}

	process.stdout.write(
		JSON.stringify({
			hookSpecificOutput: `[slash-kit] Invoking the ${skill} skill.\n\n${content.trim()}`,
		}),
	);
}

main().catch(() => process.exit(0));
