import assert from 'node:assert/strict'
import test from 'node:test'
import type { IFileChange } from '../src/git/file-change'
import { CommitChangeCache, type ICommitChangeSource } from '../src/history/commit-change-cache'

const CHANGE: IFileChange = {
  kind: 'modified',
  status: 'M',
  previousPath: 'src/index.ts',
  currentPath: 'src/index.ts',
}

test('deduplicates immutable commit-change requests and retries failures', async () => {
  const source = new RecordingCommitChangeSource()
  const cache = new CommitChangeCache(source)

  const first = cache.getChanges('/repo', 'a', null)
  const duplicate = cache.getChanges('/repo', 'a', null)
  assert.equal(first, duplicate)
  const changes = await first
  assert.equal(source.count('a'), 1)
  assert.equal(Object.isFrozen(changes), true)
  assert.equal(Object.isFrozen(changes[0]), true)

  source.failures.add('b')
  await assert.rejects(cache.getChanges('/repo', 'b', null), /changes failed/)
  source.failures.delete('b')
  await cache.getChanges('/repo', 'b', null)
  assert.equal(source.count('b'), 2)
})

test('evicts the least recently used commit-change entry', async () => {
  const source = new RecordingCommitChangeSource()
  const cache = new CommitChangeCache(source, 2)

  await cache.getChanges('/repo', 'a', null)
  await cache.getChanges('/repo', 'b', null)
  await cache.getChanges('/repo', 'a', null)
  await cache.getChanges('/repo', 'c', null)
  await cache.getChanges('/repo', 'b', null)

  assert.equal(source.count('a'), 1)
  assert.equal(source.count('b'), 2)
  assert.equal(source.count('c'), 1)
})

class RecordingCommitChangeSource implements ICommitChangeSource {
  public readonly failures = new Set<string>()
  private readonly counts = new Map<string, number>()

  public listCommitChanges(
    _repositoryPath: string,
    commit: string,
    _parentCommit: string | null,
  ): Promise<ReadonlyArray<IFileChange>> {
    this.counts.set(commit, this.count(commit) + 1)
    if (this.failures.has(commit)) return Promise.reject(new Error('changes failed'))
    return Promise.resolve([CHANGE])
  }

  public count(commit: string): number {
    return this.counts.get(commit) ?? 0
  }
}
