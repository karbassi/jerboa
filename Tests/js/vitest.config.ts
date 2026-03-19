import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  publicDir: path.resolve(__dirname, '../../Shared/Sources/MarkdownRenderer/Resources'),
  test: {
    browser: {
      enabled: true,
      provider: 'playwright',
      instances: [{ browser: 'webkit' }],
      headless: true,
    },
  },
});
