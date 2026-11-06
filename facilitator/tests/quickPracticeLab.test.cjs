// Run independently of the legacy Jest tests:
// node --test facilitator/tests/quickPracticeLab.test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const facilitatorRoot = path.resolve(__dirname, '..');
const registry = JSON.parse(fs.readFileSync(
  path.join(facilitatorRoot, 'assets/exams/labs.json'), 'utf8'
));
const lab = registry.labs.find(entry => entry.id === 'ckad-003');
const labRoot = path.join(facilitatorRoot, 'assets/exams/ckad/003');
const config = JSON.parse(fs.readFileSync(path.join(labRoot, 'config.json'), 'utf8'));
const assessment = JSON.parse(fs.readFileSync(path.join(labRoot, 'assessment.json'), 'utf8'));

test('quick practice test is registered once with a 30-minute duration', () => {
  assert.equal(registry.labs.filter(entry => entry.id === 'ckad-003').length, 1);
  assert.equal(lab.examDurationInMinutes, 30);
  assert.equal(lab.category, 'CKAD');
  assert.equal(path.join(facilitatorRoot, lab.assetPath), labRoot);
  assert.equal(config.lab, lab.id);
  assert.equal(config.questions, 'assessment.json');
  assert.equal(config.workerNodes, 1);
});

test('assessment contains exactly five independent questions', () => {
  assert.equal(assessment.questions.length, 5);
  assert.deepEqual(assessment.questions.map(question => question.id), ['1', '2', '3', '4', '5']);
  assert.equal(new Set(assessment.questions.map(question => question.namespace)).size, 5);
  for (const question of assessment.questions) {
    assert.ok(question.machineHostname);
    assert.ok(question.question);
    assert.ok(question.concepts.length > 0);
    const setup = fs.readFileSync(
      path.join(labRoot, 'scripts/setup', `q${question.id}_setup.sh`), 'utf8'
    );
    assert.ok(setup.includes(`kubectl create namespace ${question.namespace}`));
  }
});

test('grading scripts exist and question marks total 100', () => {
  let total = 0;
  for (const question of assessment.questions) {
    assert.ok(question.verification.length > 0);
    let questionMarks = 0;
    for (const step of question.verification) {
      assert.equal(step.expectedOutput, '0');
      assert.ok(Number.isInteger(step.weightage) && step.weightage > 0);
      const script = fs.readFileSync(
        path.join(labRoot, 'scripts/validation', step.verificationScriptFile), 'utf8'
      );
      assert.ok(script.startsWith('#!/bin/bash\n'));
      assert.ok(script.includes('set -euo pipefail'));
      assert.ok(script.includes(question.namespace));
      assert.ok(script.includes('exit 1'));
      questionMarks += step.weightage;
    }
    assert.equal(questionMarks, 20);
    total += questionMarks;
  }
  assert.equal(total, config.totalMarks);
  assert.equal(total, 100);
  assert.ok(config.lowScore < config.mediumScore);
  assert.ok(config.mediumScore < config.highScore);
  assert.ok(config.highScore <= total);
});

test('suggested question times add up to the exam duration', () => {
  const minutes = assessment.questions.reduce((sum, question) => {
    const match = question.question.match(/Suggested time: (\d+) minutes/);
    assert.ok(match, `Missing suggested time for question ${question.id}`);
    return sum + Number(match[1]);
  }, 0);
  assert.equal(minutes, lab.examDurationInMinutes);
});

test('solutions cover every question and shell scripts use Linux line endings', () => {
  const answers = fs.readFileSync(path.join(facilitatorRoot, config.answers), 'utf8');
  for (const question of assessment.questions) {
    assert.ok(answers.includes(`## Question ${question.id}:`));
  }
  for (const directory of ['setup', 'validation']) {
    for (const name of fs.readdirSync(path.join(labRoot, 'scripts', directory))) {
      const script = fs.readFileSync(path.join(labRoot, 'scripts', directory, name), 'utf8');
      assert.equal(script.includes('\r'), false, `${name} must use LF line endings`);
    }
  }
});
