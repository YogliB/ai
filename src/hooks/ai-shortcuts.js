#!/usr/bin/env node
// AI workflow shortcuts for Claude Code.
// Expands /alternatives, /plan, /review, /pr, /flow into skill instructions.

const readline = require('readline');

const SHORTCUTS = {
	'/alternatives':
		'Invoke the alternatives skill. Identify up to 3 viable options, run the review-alternatives skill to review them, then present with a clear recommendation and wait for the user to choose.',
	'/plan':
		'Invoke the planning skill. Produce a self-contained plan and write it to .agents/plans/<slug>.md. Run the plan review loop before finalizing.',
	'/review':
		'Invoke the review-and-fix skill on the current diff (or review-dont-fix if the user asked for read-only).',
	'/pr': 'Invoke the pr skill to create or update a GitHub pull request for the current branch.',
	'/flow':
		'Run the full workflow from RUNBOOK.md: alternatives → planning → implementation → review → PR. Ask the user before each phase if they want to continue.',
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
	const expansion = SHORTCUTS[firstWord];
	if (!expansion) process.exit(0);

	process.stdout.write(JSON.stringify({ hookSpecificOutput: `[ai] ${expansion}` }));
}

main().catch(() => process.exit(0));
