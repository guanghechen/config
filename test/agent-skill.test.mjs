import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { lstat, mkdir, mkdtemp, realpath, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import test from 'node:test'
import { linkAgentSkill, unlinkAgentSkill } from '../script/agent-skill.mjs'

test('agent skill linking is idempotent and safely reversible', async t => {
  const codexHome = await mkdtemp(path.join(tmpdir(), 'tsuki-codex-home-'))
  const destination = path.join(codexHome, 'skills', 'tsuki-agent')
  t.after(() => rm(codexHome, { recursive: true, force: true }))

  assert.equal(await linkAgentSkill({ codexHome, log: () => undefined }), destination)
  assert.equal((await lstat(destination)).isSymbolicLink(), true)
  const firstTarget = await realpath(destination)
  const wrapper = spawnSync(
    process.execPath,
    [path.join(destination, 'scripts', 'tsuki-agent.mjs'), 'invalid-command'],
    { encoding: 'utf8' },
  )
  assert.equal(wrapper.status, 1)
  assert.match(wrapper.stderr, /Usage: tsuki-agent/)

  assert.equal(await linkAgentSkill({ codexHome, log: () => undefined }), destination)
  assert.equal(await realpath(destination), firstTarget)

  assert.equal(await unlinkAgentSkill({ codexHome, log: () => undefined }), destination)
  await assert.rejects(lstat(destination), { code: 'ENOENT' })
  assert.equal(await unlinkAgentSkill({ codexHome, log: () => undefined }), destination)
})

test('agent skill linking refuses to replace or remove existing paths', async t => {
  const codexHome = await mkdtemp(path.join(tmpdir(), 'tsuki-codex-home-conflict-'))
  const destination = path.join(codexHome, 'skills', 'tsuki-agent')
  t.after(() => rm(codexHome, { recursive: true, force: true }))

  await mkdir(destination, { recursive: true })
  await assert.rejects(linkAgentSkill({ codexHome, log: () => undefined }), /Refusing to replace/)
  await assert.rejects(unlinkAgentSkill({ codexHome, log: () => undefined }), /Refusing to remove/)
})

test('linked agent skill is discoverable by the Codex prompt loader', async t => {
  const version = spawnSync('codex', ['--version'], { encoding: 'utf8' })
  if (version.error?.code === 'ENOENT') {
    t.skip('Codex CLI is unavailable.')
    return
  }
  assert.equal(version.status, 0)

  const codexHome = await mkdtemp(path.join(tmpdir(), 'tsuki-codex-discovery-'))
  t.after(() => rm(codexHome, { recursive: true, force: true }))
  await linkAgentSkill({ codexHome, log: () => undefined })
  const prompt = spawnSync('codex', ['debug', 'prompt-input', 'Use Tsuki Agent if available'], {
    encoding: 'utf8',
    env: { ...process.env, CODEX_HOME: codexHome },
    maxBuffer: 10 * 1024 * 1024,
  })
  if (prompt.status !== 0) {
    t.skip('Codex prompt debugging is unavailable.')
    return
  }
  assert.match(prompt.stdout, /tsuki-agent|Tsuki Agent/)
})
