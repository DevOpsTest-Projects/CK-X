const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const entrypoint = fs.readFileSync(path.join(root, 'entrypoint.sh'), 'utf8');
const dockerfile = fs.readFileSync(path.join(root, 'Dockerfile'), 'utf8');

test('facilitator entrypoint uses LF and a POSIX shell shebang', () => {
  assert.ok(entrypoint.startsWith('#!/bin/sh\n'));
  assert.equal(entrypoint.includes('\r'), false);
  assert.ok(entrypoint.includes('set -eu'));
});

test('asset packaging preserves scripts for subsequent container restarts', () => {
  assert.ok(entrypoint.includes('while IFS= read -r scripts_dir; do'));
  assert.ok(entrypoint.includes('tar -czf "$exam_dir/assets.tar.gz" -C "$exam_dir" scripts/'));
  assert.equal(/\brm\b/.test(entrypoint), false);
  assert.ok(entrypoint.includes('exec node /usr/src/app/src/app.js'));
});

test('Docker image normalizes scripts and validates the normalized entrypoint', () => {
  assert.ok(dockerfile.includes("-name '*.sh' -exec sed -i 's/\\r$//'"));
  assert.ok(dockerfile.includes('cp /usr/src/app/entrypoint.sh /home/nodeuser/entrypoint.sh'));
  assert.equal(dockerfile.includes('COPY entrypoint.sh /home/nodeuser/entrypoint.sh'), false);
  assert.ok(dockerfile.includes('/bin/sh -n /home/nodeuser/entrypoint.sh'));
});

test('Git preserves LF for shell scripts on future checkouts', () => {
  const attributes = fs.readFileSync(path.join(root, '..', '.gitattributes'), 'utf8');
  assert.ok(attributes.includes('*.sh text eol=lf'));
});
