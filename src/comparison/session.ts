import { Signal, type Event, type IDisposable } from '../core/signal'
import type { IFileChange } from '../git/file-change'
import type { IComparisonSnapshot, IRevisionComparison } from './model'

export interface IComparisonSource {
  resolveCommit(repositoryPath: string, reference: string, signal: AbortSignal): Promise<string>
  listChanges(
    repositoryPath: string,
    baseCommit: string,
    targetCommit: string,
    signal: AbortSignal,
  ): Promise<ReadonlyArray<IFileChange>>
}

export class ComparisonSession implements IDisposable {
  private readonly changeSignal = new Signal<IComparisonSnapshot | null>()
  private activeRequest: AbortController | null = null
  private currentSnapshot: IComparisonSnapshot | null = null
  private requestRevision = 0

  public readonly onDidChange: Event<IComparisonSnapshot | null> = this.changeSignal.event

  public constructor(private readonly comparisonSource: IComparisonSource) {}

  public get snapshot(): IComparisonSnapshot | null {
    return this.currentSnapshot
  }

  public compare(
    repositoryPath: string,
    baseRef: string,
    targetRef: string,
  ): Promise<IComparisonSnapshot | null> {
    return this.runComparison(async signal => {
      const [baseCommit, targetCommit] = await Promise.all([
        this.comparisonSource.resolveCommit(repositoryPath, baseRef, signal),
        this.comparisonSource.resolveCommit(repositoryPath, targetRef, signal),
      ])
      return { repositoryPath, baseRef, targetRef, baseCommit, targetCommit }
    })
  }

  public compareResolved(comparison: IRevisionComparison): Promise<IComparisonSnapshot | null> {
    return this.runComparison(() => Promise.resolve(comparison))
  }

  public refresh(): Promise<IComparisonSnapshot | null> {
    const snapshot = this.currentSnapshot
    if (!snapshot) return Promise.resolve(null)
    return this.compare(snapshot.repositoryPath, snapshot.baseRef, snapshot.targetRef)
  }

  public swap(): Promise<IComparisonSnapshot | null> {
    const snapshot = this.currentSnapshot
    if (!snapshot) return Promise.resolve(null)
    return this.compare(snapshot.repositoryPath, snapshot.targetRef, snapshot.baseRef)
  }

  public clear(): void {
    this.cancelActiveRequest()
    this.requestRevision += 1
    this.currentSnapshot = null
    this.changeSignal.emit(null)
  }

  public dispose(): void {
    this.clear()
    this.changeSignal.dispose()
  }

  private async runComparison(
    resolveComparison: (signal: AbortSignal) => Promise<IRevisionComparison>,
  ): Promise<IComparisonSnapshot | null> {
    this.cancelActiveRequest()
    const request = new AbortController()
    const revision = ++this.requestRevision
    this.activeRequest = request

    try {
      const comparison = await resolveComparison(request.signal)
      if (revision !== this.requestRevision) return null
      const changes = await this.comparisonSource.listChanges(
        comparison.repositoryPath,
        comparison.baseCommit,
        comparison.targetCommit,
        request.signal,
      )
      if (revision !== this.requestRevision) return null

      const snapshot: IComparisonSnapshot = Object.freeze({
        revision,
        repositoryPath: comparison.repositoryPath,
        baseRef: comparison.baseRef.trim(),
        targetRef: comparison.targetRef.trim(),
        baseCommit: comparison.baseCommit,
        targetCommit: comparison.targetCommit,
        changes: Object.freeze([...changes]),
      })
      this.currentSnapshot = snapshot
      this.changeSignal.emit(snapshot)
      return snapshot
    } catch (cause) {
      request.abort()
      if (revision !== this.requestRevision) return null
      throw cause
    } finally {
      if (this.activeRequest === request) this.activeRequest = null
    }
  }

  private cancelActiveRequest(): void {
    this.activeRequest?.abort()
    this.activeRequest = null
  }
}
