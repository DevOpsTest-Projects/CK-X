// Run with: node --test facilitator/tests/ckaTroubleshootingLab.test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const facilitatorRoot = path.resolve(__dirname, '..');
const registry = JSON.parse(fs.readFileSync(
  path.join(facilitatorRoot, 'assets/exams/labs.json'), 'utf8'
));
const lab = registry.labs.find(entry => entry.id === 'cka-003');
const labRoot = path.join(facilitatorRoot, 'assets/exams/cka/003');
const config = JSON.parse(fs.readFileSync(path.join(labRoot, 'config.json'), 'utf8'));
const assessment = JSON.parse(fs.readFileSync(path.join(labRoot, 'assessment.json'), 'utf8'));

test('CKA troubleshooting test is registered with a 30-minute duration', () => {
  assert.equal(registry.labs.filter(entry => entry.id === 'cka-003').length, 1);
  assert.equal(lab.category, 'CKA');
  assert.equal(lab.examDurationInMinutes, 30);
  assert.equal(lab.difficulty, 'Medium');
  assert.equal(path.join(facilitatorRoot, lab.assetPath), labRoot);
  assert.equal(config.lab, lab.id);
  assert.equal(config.workerNodes, 1);
});

test('assessment contains five independent troubleshooting questions', () => {
  assert.equal(assessment.questions.length, 5);
  assert.deepEqual(assessment.questions.map(question => question.id), ['1', '2', '3', '4', '5']);
  assert.equal(new Set(assessment.questions.map(question => question.namespace)).size, 5);
  for (const question of assessment.questions) {
    assert.match(question.question, /Suggested time: 6 minutes/);
    assert.match(question.question, /Marks: 20/);
    assert.ok(question.concepts.includes('troubleshooting'));
    const setup = fs.readFileSync(
      path.join(labRoot, 'scripts/setup', `q${question.id}_setup.sh`), 'utf8'
    );
    assert.ok(setup.includes(`kubectl create namespace ${question.namespace}`));
  }
});

test('grading scripts and solutions cover all 100 marks', () => {
  let totalMarks = 0;
  for (const question of assessment.questions) {
    let questionMarks = 0;
    for (const step of question.verification) {
      assert.equal(step.expectedOutput, '0');
      assert.ok(Number.isInteger(step.weightage) && step.weightage > 0);
      const scriptPath = path.join(labRoot, 'scripts/validation', step.verificationScriptFile);
      const script = fs.readFileSync(scriptPath, 'utf8');
      assert.ok(script.startsWith('#!/bin/bash\n'));
      assert.ok(script.includes('set -euo pipefail'));
      assert.ok(script.includes(question.namespace));
      assert.ok(script.includes('exit 1'));
      questionMarks += step.weightage;
    }
    assert.equal(questionMarks, 20);
    totalMarks += questionMarks;
  }

  const answers = fs.readFileSync(path.join(facilitatorRoot, config.answers), 'utf8');
  for (const question of assessment.questions) {
    assert.ok(answers.includes(`## Question ${question.id}:`));
  }
  assert.equal(totalMarks, config.totalMarks);
});

test('suggested question times add up to 30 minutes', () => {
  const minutes = assessment.questions.reduce((sum, question) => {
    const match = question.question.match(/Suggested time: (\d+) minutes/);
    assert.ok(match, `Missing suggested time for question ${question.id}`);
    return sum + Number(match[1]);
  }, 0);
  assert.equal(minutes, lab.examDurationInMinutes);
});
