import { defineConfig } from 'vitest/config';

// One emulator, one database. `clearFirestore()` wipes the whole project, so
// two test files running at the same time would wipe each other's seed data
// mid-test. Everything here runs in one process, one file at a time.
export default defineConfig({
  test: {
    environment: 'node',
    fileParallelism: false,
    sequence: { concurrent: false },
    // The first connection waits for the emulator; a rules evaluation is
    // otherwise a millisecond affair.
    testTimeout: 20000,
    hookTimeout: 30000,
    reporters: ['verbose'],
  },
});
