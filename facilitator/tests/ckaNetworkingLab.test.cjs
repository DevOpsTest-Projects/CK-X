const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const registry = JSON.parse(fs.readFileSync(path.join(root, 'assets/exams/labs.json'), 'utf8'));
const lab = registry.labs.find(entry => entry.id === 'cka-003');
const assets = path.join(root, 'assets/exams/cka/003');
const config = JSON.parse(fs.readFileSync(path.join(assets, 'config.json'), 'utf8'));
const { questions } = JSON.parse(fs.readFileSync(path.join(assets, config.questions), 'utf8'));

test('CKA networking test is registered once with a half-hour timer', () => {
  assert.equal(registry.labs.filter(entry => entry.id === 'cka-003').length, 1);
  assert.equal(lab.category, 'CKA');
  assert.equal(lab.examDurationInMinutes, 30);
  assert.equal(path.join(root, lab.assetPath), assets);
  assert.equal(config.lab, lab.id);
  assert.equal(config.workerNodes, 1);
  assert.ok(lab.warmUpTimeInSeconds > 0);
});

test('five independent questions have consecutive IDs and total 30 suggested minutes', () => {
  assert.equal(questions.length, 5);
  assert.deepEqual(questions.map(question => question.id), ['1', '2', '3', '4', '5']);
  assert.equal(new Set(questions.map(question => question.namespace)).size, 5);
  let minutes = 0;
  for (const question of questions) {
    assert.equal(question.machineHostname, 'ckad9999');
    const match = question.question.match(/Suggested time: (\d+) minutes/);
    assert.ok(match);
    minutes += Number(match[1]);
    const setup = fs.readFileSync(path.join(assets, 'scripts/setup', `q${question.id}_setup.sh`), 'utf8');
    assert.ok(setup.includes(`create_namespace ${question.namespace}`));
  }
  assert.equal(minutes, 30);
});

test('concept coverage includes all Services & Networking syllabus objectives', () => {
  const concepts = new Set(questions.flatMap(question => question.concepts));
  for (const concept of ['pod-connectivity', 'networkpolicies', 'clusterip',
    'nodeport', 'loadbalancer', 'endpointslices', 'gateway-api', 'ingress',
    'ingress-controllers', 'coredns']) {
    assert.ok(concepts.has(concept), `Missing objective: ${concept}`);
  }
});

test('grading supports partial credit and totals 20 marks per question, 100 overall', () => {
  let total = 0;
  const scriptNames = [];
  for (const question of questions) {
    assert.ok(question.verification.length > 1);
    assert.equal(new Set(question.verification.map(step => step.id)).size, question.verification.length);
    let marks = 0;
    for (const step of question.verification) {
      assert.equal(step.expectedOutput, '0');
      assert.ok(Number.isInteger(step.weightage) && step.weightage > 0);
      assert.ok(fs.existsSync(path.join(assets, 'scripts/validation', step.verificationScriptFile)));
      scriptNames.push(step.verificationScriptFile);
      marks += step.weightage;
    }
    assert.equal(marks, 20);
    total += marks;
  }
  assert.equal(new Set(scriptNames).size, scriptNames.length);
  assert.equal(total, config.totalMarks);
  assert.equal(total, 100);
  assert.ok(config.lowScore < config.mediumScore && config.mediumScore < config.highScore);
});

test('shared controller infrastructure is installed before the questions', () => {
  const setupDirectory = path.join(assets, 'scripts/setup');
  assert.equal(fs.readdirSync(setupDirectory).sort()[0], 'q0_setup.sh');
  const setup = fs.readFileSync(path.join(setupDirectory, 'q0_setup.sh'), 'utf8');
  for (const setting of ['gateway-api/v1.2.1', '--version 34.4.1',
    'providers.kubernetesGateway.enabled=true', 'gateway.enabled=false',
    'ingressClass.isDefaultClass=false', 'gatewayClass.name=cka-net-traefik',
    '--wait --timeout=240s', 'gatewayclass/cka-net-traefik']) {
    assert.ok(setup.includes(setting), `Missing prerequisite: ${setting}`);
  }
  assert.equal(setup.includes('--force-conflicts'), false);
});

test('every shell script is LF and its shared helper is packaged inside scripts', () => {
  const scripts = path.join(assets, 'scripts');
  let count = 0;
  for (const directory of [scripts, path.join(scripts, 'setup'), path.join(scripts, 'validation')]) {
    for (const file of fs.readdirSync(directory).filter(file => file.endsWith('.sh'))) {
      const text = fs.readFileSync(path.join(directory, file), 'utf8');
      assert.ok(text.startsWith('#!/bin/bash\n'), file);
      assert.equal(text.includes('\r'), false, `${file} must have LF endings`);
      assert.ok(text.includes('set -euo pipefail'), file);
      if (directory !== scripts) {
        assert.ok(text.includes('source "$(dirname "$0")/../common.sh"'), file);
      }
      count++;
    }
  }
  assert.equal(count, 19);
});

test('solutions and domain scope are documented for all five questions', () => {
  const answers = fs.readFileSync(path.join(root, config.answers), 'utf8');
  const readme = fs.readFileSync(path.join(assets, 'README.md'), 'utf8');
  for (const question of questions) {
    assert.ok(answers.includes(`## Question ${question.id}:`));
  }
  assert.ok(answers.includes('port: 8000'));
  assert.ok(answers.includes('from: Same'));
  assert.ok(readme.includes('CKA_Curriculum_v1.37.pdf'));
  assert.ok(readme.includes('public/cloud IP'));
  assert.ok(readme.includes('docker compose up -d --build --no-deps facilitator'));
});
