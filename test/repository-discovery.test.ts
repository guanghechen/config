import assert from 'node:assert/strict'
import test from 'node:test'
import {
  resolveRepositoryCandidates,
  type IRepositoryResolver,
} from '../src/app/shared/repository-discovery'

test('deduplicates candidates and resolves repositories concurrently', async () => {
  const resolver = new RecordingRepositoryResolver()
  const repositories = await resolveRepositoryCandidates(
    ['/workspace/a', '/workspace/a', '/workspace/b', '/invalid'],
    resolver,
  )

  assert.deepEqual(resolver.candidates, ['/workspace/a', '/workspace/b', '/invalid'])
  assert.equal(resolver.maxConcurrency, 3)
  assert.deepEqual(repositories, ['/repository'])
})

class RecordingRepositoryResolver implements IRepositoryResolver {
  public activeCount = 0
  public readonly candidates: string[] = []
  public maxConcurrency = 0

  public async resolveRepository(candidatePath: string): Promise<string> {
    this.candidates.push(candidatePath)
    this.activeCount += 1
    this.maxConcurrency = Math.max(this.maxConcurrency, this.activeCount)
    await Promise.resolve()
    this.activeCount -= 1
    if (candidatePath === '/invalid') throw new Error('not a repository')
    return '/repository'
  }
}
