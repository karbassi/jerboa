import { defineConfig } from 'vitest/config';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  publicDir: path.resolve(__dirname, '../../Shared/Sources/MarkdownRenderer/Resources'),
  test: {
    browser: {
      enabled: true,
      provider: 'playwright',
      instances: [{ browser: 'webkit' }],
      headless: true,
      screenshotFailures: false,
    },
  },
});
