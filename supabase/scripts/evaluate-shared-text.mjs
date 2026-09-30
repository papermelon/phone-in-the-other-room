import { readFile } from 'node:fs/promises';
import { sharedTextDecision } from '../functions/_shared/shared-text-moderation.ts';

// Explicit opt-in: this sends repository-owned synthetic fixtures, never app data.
if (!process.argv.includes('--live')) {
  console.log('Run with --live and OPENAI_MODERATION_API_KEY to evaluate synthetic language cases.');
  process.exit(0);
}
const key = process.env.OPENAI_MODERATION_API_KEY;
if (!key) { console.error('OPENAI_MODERATION_API_KEY is not configured.'); process.exit(1); }
const cases = JSON.parse(await readFile(new URL('../tests/fixtures/shared_text_language_cases.json', import.meta.url), 'utf8'));
try {
  const response = await fetch('https://api.openai.com/v1/moderations', {
    method: 'POST', headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: 'omni-moderation-latest', input: cases.map(c => c.text) }),
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) throw new Error(`Moderation endpoint returned HTTP ${response.status}`);
  const body = await response.json();
  if (!Array.isArray(body.results) || body.results.length !== cases.length) throw new Error('Incomplete moderation results');
  let failures = 0;
  for (let i = 0; i < cases.length; i++) {
    const decision = sharedTextDecision(body.results[i]);
    const passed = cases[i].expected.includes(decision);
    if (!passed) failures++;
    console.log(JSON.stringify({ id: cases[i].id, decision, passed }));
  }
  const model = typeof body.model === 'string' && /^omni-moderation-[a-z0-9-]{1,48}$/.test(body.model) ? body.model : 'unknown';
  console.log(JSON.stringify({ model, passed: cases.length - failures, failed: failures }));
  process.exitCode = failures ? 1 : 0;
} catch (error) {
  console.error('Moderation evaluation failed. Check credentials, availability and response shape.');
  process.exitCode = 1;
}
