import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { describe, it } from 'node:test'

const helperPath = path.join(import.meta.dirname, '../setup/nix/bot/step.bash')
const ansiPattern = /\u001B\[[0-9;]*m/g
const bashExecutable = process.platform === 'win32'
  ? [
      process.env.APP_HOME_GIT && path.join(process.env.APP_HOME_GIT, 'bin/bash.exe'),
      'C:\\app\\git\\bin\\bash.exe',
      'C:\\Program Files\\Git\\bin\\bash.exe',
    ].find(candidate => candidate && fs.existsSync(candidate)) ?? 'bash'
  : 'bash'
function normalizeOutput(value) {
  return value.replaceAll('\r\n', '\n').trim()
}

function runStepScript(body) {
  const result = spawnSync(
    bashExecutable,
    [
      '--noprofile',
      '--norc',
      '-c',
      `source ${JSON.stringify(helperPath.replaceAll('\\', '/'))}\n${body}`,
    ],
    { encoding: 'utf8' },
  )
  return {
    status: result.status,
    rawOutput: normalizeOutput(result.stdout),
    output: normalizeOutput(result.stdout.replaceAll(ansiPattern, '')),
  }
}

describe('bash setup step forest', () => {
  it('renders flat sections containing independent rounded trees', () => {
    const result = runStepScript(String.raw`
      ghc_section '' demo
      ghc_step '󰒓' alpha bash -c 'printf "\033[35mline one\033[0m\n\nline two\nstale\rcurrent\n"'
      ghc_step_skip '' beta 'not applicable'
      ghc_step_summary
    `)

    assert.equal(result.status, 0)
    assert.equal(result.output, [
      ' demo',
      '╭─ 󰒓 alpha',
      '│  line one',
      '│  line two',
      '│  current',
      '╰─ ✓ done',
      '',
      '╭─  beta',
      '╰─ ○ skipped — not applicable',
      '',
      ' summary',
      '╭─ 󰒓 setup',
      '╰─ ✓ all sections completed',
    ].join('\n'))
    assert.doesNotMatch(result.output, /[├└]/)
    assert.doesNotMatch(result.output, /●/)
    assert.doesNotMatch(result.output, /stale/)

    const railLines = result.rawOutput
      .split('\n')
      .filter(line => /[╭│╰]/.test(line.replaceAll(ansiPattern, '')))
    for (const line of railLines) assert.match(line, /^\u001B\[90m[╭│╰]/)
    assert.ok(result.rawOutput.includes(
      '\u001B[90m│\u001B[0m  \u001B[35mline one\u001B[0m',
    ))
    assert.ok(result.rawOutput.includes(
      '\u001B[90m╭─\u001B[0m \u001B[96m󰒓 alpha\u001B[0m',
    ))
  })

  it('collects optional failures with their section path', () => {
    const result = runStepScript(String.raw`
      ghc_section '' environment
      ghc_step_optional '' node bash -c 'printf "diagnostic\n"; exit 7'
      ghc_step_optional '' theme bash -c 'exit 8'
      ghc_step_summary
    `)

    assert.equal(result.status, 1)
    assert.equal(result.output, [
      ' environment',
      '╭─  node',
      '│  diagnostic',
      '╰─ ✗ failed (exit 7); continuing',
      '',
      '╭─  theme',
      '╰─ ✗ failed (exit 8); continuing',
      '',
      ' summary',
      '╭─ 󰒓 setup',
      '│  environment / node',
      '│  environment / theme',
      '╰─ ✗ completed with 2 failed steps',
    ].join('\n'))
  })

  it('aborts a required step with the original exit code', () => {
    const result = runStepScript(String.raw`
      ghc_section '' bootstrap
      ghc_step '' broken bash -c 'exit 23'
      printf 'unreachable\n'
    `)

    assert.equal(result.status, 23)
    assert.doesNotMatch(result.output, /unreachable/)
    assert.match(result.output, /╰─ ✗ failed \(exit 23\); aborting$/)
  })

  it('keeps environment mutations and clears the parent command cache', () => {
    const result = runStepScript(String.raw`
      set_marker() { marker=ready; }
      hash -p /stale/path/demo demo
      ghc_section '' bootstrap
      ghc_step_in_place '' environment set_marker
      test "$marker" = ready
      if hash -t demo >/dev/null 2>&1; then exit 91; fi
      ghc_step_summary
    `)

    assert.equal(result.status, 0)
    assert.match(result.output, /╰─ ✓ all sections completed$/)
  })

  it('keeps local settings outside the step wrapper', () => {
    for (const relativePath of [
      '../setup/nix/setup.bash',
      '../setup/nix-remote/setup.bash',
      '../setup/osx/setup.bash',
    ]) {
      const content = fs.readFileSync(path.join(import.meta.dirname, relativePath), 'utf8')
      assert.match(content, /^\s*ghc_sync_kit_repo \|\| exit \$\?$/m)
      assert.doesNotMatch(content, /ghc_step[^\n]*local settings/)
    }
  })
})
