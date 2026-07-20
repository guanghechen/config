import type { IGitCommit } from './commit'

const COMMIT_FIELD_COUNT = 6
const HASH_PATTERN = /^[0-9a-f]{40,64}$/i
const SHORT_HASH_PATTERN = /^[0-9a-f]{4,64}$/i

export function parseCommitLog(output: Buffer): ReadonlyArray<IGitCommit> {
  if (output.length === 0) return []

  const fields = output.toString('utf8').split('\0')
  if (fields.at(-1) === '') fields.pop()

  const commits: IGitCommit[] = []
  let index = 0

  while (index < fields.length) {
    if (fields.length - index < COMMIT_FIELD_COUNT + 1) {
      throw new Error('Malformed git log output: incomplete commit record.')
    }

    const hash = requireField(fields, index, 'hash')
    const shortHash = requireField(fields, index + 1, 'short hash')
    const parentField = readField(fields, index + 2, 'parents')
    const authorName = readField(fields, index + 3, 'author name')
    const authoredAt = requireField(fields, index + 4, 'author date')
    const subject = readField(fields, index + 5, 'subject')
    const delimiter = readField(fields, index + COMMIT_FIELD_COUNT, 'record delimiter')
    index += COMMIT_FIELD_COUNT + 1

    if (delimiter !== '') throw new Error('Malformed git log output: missing record delimiter.')
    assertHash(hash, 'commit')
    if (!SHORT_HASH_PATTERN.test(shortHash)) {
      throw new Error('Malformed git log output: invalid short hash.')
    }

    const parents = parentField ? parentField.split(' ') : []
    for (const parent of parents) assertHash(parent, 'parent')
    if (Number.isNaN(Date.parse(authoredAt))) {
      throw new Error('Malformed git log output: invalid author date.')
    }

    commits.push(
      Object.freeze({
        hash,
        shortHash,
        parents: Object.freeze(parents),
        authorName,
        authoredAt,
        subject,
      }),
    )
  }

  return Object.freeze(commits)
}

function readField(fields: ReadonlyArray<string>, index: number, label: string): string {
  const value = fields[index]
  if (value !== undefined) return value
  throw new Error(`Malformed git log output: missing ${label}.`)
}

function requireField(fields: ReadonlyArray<string>, index: number, label: string): string {
  const value = readField(fields, index, label)
  if (value) return value
  throw new Error(`Malformed git log output: missing ${label}.`)
}

function assertHash(value: string, label: string): void {
  if (!HASH_PATTERN.test(value)) {
    throw new Error(`Malformed git log output: invalid ${label} hash.`)
  }
}
