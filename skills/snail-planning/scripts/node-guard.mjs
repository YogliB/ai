/**
 * Fail fast with an actionable message when the runtime is below the
 * supported Node baseline (current LTS, 24+).
 *
 * @param {string} tool - script name used in the error message
 */
export function requireNode24(tool) {
	const major = Number(process.versions.node.split('.')[0]);
	if (major < 24) {
		console.error(
			`${tool}: Node 24+ (current LTS) is required; found ${process.version}. Install from https://nodejs.org/ and re-run.`,
		);
		process.exit(1);
	}
}
