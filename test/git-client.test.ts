import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { mkdir, mkdtemp, realpath, rename, rm, unlink, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import test from 'node:test'
import { GitBlobDisplayError, GitClient } from '../src/git/git-client'

test('resolves commits, detects structural changes, and reads immutable blobs', async t => {
  const repositoryPath = await mkdtemp(path.join(tmpdir(), 'vsgit-test-'))
  t.after(() => rm(repositoryPath, { force: true, recursive: true }))

  git(repositoryPath, 'init', '--quiet')
  git(repositoryPath, 'config', 'user.name', 'VSGit Test')
  git(repositoryPath, 'config', 'user.email', 'vsgit@example.invalid')
  await writeFile(path.join(repositoryPath, 'deleted.txt'), 'deleted\n')
  await writeFile(path.join(repositoryPath, 'modified.txt'), 'before\n')
  await mkdir(path.join(repositoryPath, 'old'), { recursive: true })
  await writeFile(path.join(repositoryPath, 'old', 'name.txt'), 'rename me\n')
  git(repositoryPath, 'add', '.')
  git(repositoryPath, 'commit', '--quiet', '-m', 'base')
  const baseCommit = git(repositoryPath, 'rev-parse', 'HEAD')

  await unlink(path.join(repositoryPath, 'deleted.txt'))
  await writeFile(path.join(repositoryPath, 'modified.txt'), 'after\n')
  await writeFile(path.join(repositoryPath, 'added file.txt'), 'added\n')
  await writeFile(path.join(repositoryPath, 'binary.bin'), Buffer.from([0, 1, 2, 3]))
  await mkdir(path.join(repositoryPath, 'new'), { recursive: true })
  await rename(
    path.join(repositoryPath, 'old', 'name.txt'),
    path.join(repositoryPath, 'new', 'name.txt'),
  )
  git(repositoryPath, 'add', '--all')
  git(repositoryPath, 'commit', '--quiet', '-m', 'target')

  const client = new GitClient()
  const targetCommit = await client.resolveCommit(repositoryPath, 'HEAD')
  assert.equal(
    await client.resolveRepository(path.join(repositoryPath, 'new')),
    await realpath(repositoryPath),
  )
  assert.equal(await client.resolveCommit(repositoryPath, baseCommit.slice(0, 12)), baseCommit)

  const firstPage = await client.listCommits(repositoryPath, 1)
  assert.equal(firstPage.hasMore, true)
  assert.equal(firstPage.commits.length, 1)
  assert.equal(firstPage.commits[0]?.hash, targetCommit)
  assert.deepEqual(firstPage.commits[0]?.parents, [baseCommit])

  const fullPage = await client.listCommits(repositoryPath, 10)
  assert.equal(fullPage.hasMore, false)
  assert.deepEqual(
    fullPage.commits.map(commit => commit.hash),
    [targetCommit, baseCommit],
  )

  const changes = await client.listChanges(repositoryPath, baseCommit, targetCommit)
  assert.deepEqual(
    changes.map(change => [change.status, change.previousPath, change.currentPath]),
    [
      ['A', null, 'added file.txt'],
      ['A', null, 'binary.bin'],
      ['D', 'deleted.txt', null],
      ['M', 'modified.txt', 'modified.txt'],
      ['R100', 'old/name.txt', 'new/name.txt'],
    ],
  )
  assert.deepEqual(
    await client.listCommitChanges(repositoryPath, targetCommit, baseCommit),
    changes,
  )
  assert.deepEqual(
    (await client.listCommitChanges(repositoryPath, baseCommit, null)).map(change => [
      change.status,
      change.previousPath,
      change.currentPath,
    ]),
    [
      ['A', null, 'deleted.txt'],
      ['A', null, 'modified.txt'],
      ['A', null, 'old/name.txt'],
    ],
  )
  assert.equal(
    await client.readTextFile(repositoryPath, targetCommit, 'added file.txt', 1024),
    'added\n',
  )
  await assert.rejects(
    client.readTextFile(repositoryPath, targetCommit, 'added file.txt', 1),
    GitBlobDisplayError,
  )
  await assert.rejects(
    client.readTextFile(repositoryPath, targetCommit, 'binary.bin', 1024),
    GitBlobDisplayError,
  )
  await assert.rejects(client.listCommits(repositoryPath, 0), /Commit page size/)
})

function git(repositoryPath: string, ...args: string[]): string {
  return execFileSync('git', ['-C', repositoryPath, ...args], {
    encoding: 'utf8',
  }).trim()
}
