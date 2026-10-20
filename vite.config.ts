import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import deployment from './deployment.json' with { type: 'json' };

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  base: deployment.base,

  server: {
    host: 'localhost',
    port: 3000,
  },
  test: {
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
    globals: true,
  },
});
