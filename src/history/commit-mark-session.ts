import type { IDisposable } from '../core/signal'
import { Signal, type Event } from '../core/signal'
import type { ICommitHistorySnapshot } from './model'

const RESOLVED_COMMIT_PATTERN = /^[0-9a-f]{40,64}$/i
const MAX_MARKS = 2

export type CommitMarkResult = 'marked' | 'already-marked' | 'full' | 'stale'

export class CommitMarkSession implements IDisposable {
  private readonly changeSignal = new Signal<ReadonlyArray<string>>()
  private activeRepositoryPath: string | null = null
  private availableCommitHashes: ReadonlySet<string> = new Set()
  private markedCommitHashes: ReadonlyArray<string> = Object.freeze([])

  public readonly onDidChange: Event<ReadonlyArray<string>> = this.changeSignal.event

  public get count(): number {
    return this.markedCommitHashes.length
  }

  public get markedHashes(): ReadonlyArray<string> {
    return this.markedCommitHashes
  }

  public reconcile(snapshot: ICommitHistorySnapshot | null): void {
    const repositoryPath = snapshot?.repositoryPath ?? null
    const availableCommitHashes = new Set(snapshot?.commits.map(commit => commit.hash) ?? [])
    const nextValues =
      repositoryPath === this.activeRepositoryPath
        ? this.markedCommitHashes.filter(hash => availableCommitHashes.has(hash))
        : []

    this.activeRepositoryPath = repositoryPath
    this.availableCommitHashes = availableCommitHashes
    this.replace(nextValues)
  }

  public mark(repositoryPath: string, commitHash: string): CommitMarkResult {
    if (
      repositoryPath !== this.activeRepositoryPath ||
      !RESOLVED_COMMIT_PATTERN.test(commitHash) ||
      !this.availableCommitHashes.has(commitHash)
    ) {
      return 'stale'
    }
    if (this.markedCommitHashes.includes(commitHash)) return 'already-marked'
    if (this.markedCommitHashes.length >= MAX_MARKS) return 'full'

    this.replace([...this.markedCommitHashes, commitHash])
    return 'marked'
  }

  public unmark(repositoryPath: string, commitHash: string): boolean {
    if (
      repositoryPath !== this.activeRepositoryPath ||
      !this.markedCommitHashes.includes(commitHash)
    ) {
      return false
    }
    this.replace(this.markedCommitHashes.filter(hash => hash !== commitHash))
    return true
  }

  public isMarked(repositoryPath: string, commitHash: string): boolean {
    return (
      repositoryPath === this.activeRepositoryPath && this.markedCommitHashes.includes(commitHash)
    )
  }

  public clear(): void {
    this.replace([])
  }

  public dispose(): void {
    this.activeRepositoryPath = null
    this.availableCommitHashes = new Set()
    this.markedCommitHashes = Object.freeze([])
    this.changeSignal.dispose()
  }

  private replace(values: ReadonlyArray<string>): void {
    if (arraysEqual(this.markedCommitHashes, values)) return
    this.markedCommitHashes = Object.freeze([...values])
    this.changeSignal.emit(this.markedCommitHashes)
  }
}

function arraysEqual(left: ReadonlyArray<string>, right: ReadonlyArray<string>): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index])
}
