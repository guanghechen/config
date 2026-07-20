import type { Disposable } from 'vscode'
import type { ICommitHistorySnapshot } from './model'

const RESOLVED_COMMIT_PATTERN = /^[0-9a-f]{40,64}$/i
const MAX_MARKS = 2

export type CommitMarkResult = 'marked' | 'already-marked' | 'full' | 'stale'

export class CommitMarkSession implements Disposable {
  private readonly listeners = new Set<(marks: ReadonlyArray<string>) => void>()
  private availableHashes: ReadonlySet<string> = new Set()
  private repositoryPath: string | null = null
  private values: ReadonlyArray<string> = Object.freeze([])

  public get count(): number {
    return this.values.length
  }

  public get markedHashes(): ReadonlyArray<string> {
    return this.values
  }

  public onDidChange(listener: (marks: ReadonlyArray<string>) => void): Disposable {
    this.listeners.add(listener)
    return { dispose: () => this.listeners.delete(listener) }
  }

  public reconcile(snapshot: ICommitHistorySnapshot | null): void {
    const repositoryPath = snapshot?.repositoryPath ?? null
    const availableHashes = new Set(snapshot?.commits.map(commit => commit.hash) ?? [])
    const nextValues =
      repositoryPath === this.repositoryPath
        ? this.values.filter(hash => availableHashes.has(hash))
        : []

    this.repositoryPath = repositoryPath
    this.availableHashes = availableHashes
    this.replace(nextValues)
  }

  public mark(repositoryPath: string, commitHash: string): CommitMarkResult {
    if (
      repositoryPath !== this.repositoryPath ||
      !RESOLVED_COMMIT_PATTERN.test(commitHash) ||
      !this.availableHashes.has(commitHash)
    ) {
      return 'stale'
    }
    if (this.values.includes(commitHash)) return 'already-marked'
    if (this.values.length >= MAX_MARKS) return 'full'

    this.replace([...this.values, commitHash])
    return 'marked'
  }

  public unmark(repositoryPath: string, commitHash: string): boolean {
    if (repositoryPath !== this.repositoryPath || !this.values.includes(commitHash)) return false
    this.replace(this.values.filter(hash => hash !== commitHash))
    return true
  }

  public isMarked(repositoryPath: string, commitHash: string): boolean {
    return repositoryPath === this.repositoryPath && this.values.includes(commitHash)
  }

  public clear(): void {
    this.replace([])
  }

  public dispose(): void {
    this.repositoryPath = null
    this.availableHashes = new Set()
    this.values = Object.freeze([])
    this.listeners.clear()
  }

  private replace(values: ReadonlyArray<string>): void {
    if (arraysEqual(this.values, values)) return
    this.values = Object.freeze([...values])
    for (const listener of this.listeners) listener(this.values)
  }
}

function arraysEqual(left: ReadonlyArray<string>, right: ReadonlyArray<string>): boolean {
  return left.length === right.length && left.every((value, index) => value === right[index])
}
