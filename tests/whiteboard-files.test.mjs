import assert from 'node:assert/strict'
import { test } from 'node:test'
import { mkdtemp, readFile, readdir, rm, stat, symlink, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import {
  FileExistsError,
  createVersionedText,
  textRevision,
} from '../server/util/versioned-text.ts'

test('concurrent create-only writes publish exactly one complete file and clean up temporary files', async t => {
  const directory = await mkdtemp(path.join(tmpdir(), 'yoz-create-'))
  t.after(() => rm(directory, { recursive: true, force: true }))
  const filepath = path.join(directory, 'board.whiteboard')
  const contents = Array.from({ length: 8 }, (_, index) => `${index}: ${'白板'.repeat(5000)}`)
  const results = await Promise.allSettled(
    contents.map(content => createVersionedText(filepath, content)),
  )
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1)
  const winner = results.findIndex(result => result.status === 'fulfilled')
  assert.equal(await readFile(filepath, 'utf8'), contents[winner])
  assert.equal(results[winner].value.revision, textRevision(contents[winner]))
  assert.ok(
    results
      .filter(result => result.status === 'rejected')
      .every(result => result.reason instanceof FileExistsError),
  )
  assert.equal((await stat(filepath)).mode & 0o777, 0o600)
  assert.deepEqual(await readdir(directory), ['board.whiteboard'])
})

test('create-only writes preserve existing files and symlink destinations', async t => {
  const directory = await mkdtemp(path.join(tmpdir(), 'yoz-create-'))
  t.after(() => rm(directory, { recursive: true, force: true }))
  const original = path.join(directory, 'original.whiteboard')
  const alias = path.join(directory, 'alias.whiteboard')
  await writeFile(original, 'original content')
  await symlink(original, alias)
  await assert.rejects(createVersionedText(original, 'replacement'), FileExistsError)
  await assert.rejects(createVersionedText(alias, 'replacement'), FileExistsError)
  assert.equal(await readFile(original, 'utf8'), 'original content')
  assert.deepEqual((await readdir(directory)).sort(), ['alias.whiteboard', 'original.whiteboard'])
})
