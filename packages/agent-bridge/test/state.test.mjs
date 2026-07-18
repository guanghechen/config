import assert from 'node:assert/strict'
import { access, mkdtemp, rm, stat } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import test from 'node:test'
import { readState, removeState, writeState } from '../src/state.mjs'

test('broker state is private, atomic, and removed only by its owner', async t => {
  const directory = await mkdtemp(join(tmpdir(), 'tsuki-agent-state-test-'))
  const statePath = join(directory, 'broker.json')
  const firstToken = 'a'.repeat(32)
  const secondToken = 'b'.repeat(32)

  t.after(() => rm(directory, { recursive: true, force: true }))

  await writeState({ port: 7072, clientToken: firstToken }, statePath)
  assert.equal((await stat(statePath)).mode & 0o777, 0o600)
  assert.deepEqual(await readState(statePath), { port: 7072, clientToken: firstToken })

  await writeState({ port: 7073, clientToken: secondToken }, statePath)
  await removeState(statePath, firstToken)
  await access(statePath)

  await removeState(statePath, secondToken)
  await assert.rejects(access(statePath))
})
