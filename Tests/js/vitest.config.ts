import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
	publicDir: path.resolve(
		__dirname,
		"../../Shared/Sources/MarkdownRenderer/Resources",
	),
	test: {
		browser: {
			enabled: true,
			provider: "playwright",
			instances: [{ browser: "webkit" }],
			headless: true,
			screenshotFailures: false,
		},
	},
});
