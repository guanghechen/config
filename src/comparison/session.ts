import { EventEmitter, type Disposable, type Event } from 'vscode'
import type { IComparisonSnapshot } from './model'
import { GitClient } from '../git/git-client'

export class ComparisonSession implements Disposable {
  private readonly changeEmitter = new EventEmitter<IComparisonSnapshot | null>()
  private currentSnapshot: IComparisonSnapshot | null = null
  private requestRevision = 0

  public readonly onDidChange: Event<IComparisonSnapshot | null> = this.changeEmitter.event

  public constructor(private readonly gitClient: GitClient) {}

  public get snapshot(): IComparisonSnapshot | null {
    return this.currentSnapshot
  }

  public async compare(
    repositoryPath: string,
    baseRef: string,
    targetRef: string,
  ): Promise<IComparisonSnapshot | null> {
    const revision = ++this.requestRevision
    const [baseCommit, targetCommit] = await Promise.all([
      this.gitClient.resolveCommit(repositoryPath, baseRef),
      this.gitClient.resolveCommit(repositoryPath, targetRef),
    ])
    const changes = await this.gitClient.listChanges(repositoryPath, baseCommit, targetCommit)
    if (revision !== this.requestRevision) return null

    const snapshot: IComparisonSnapshot = Object.freeze({
      revision,
      repositoryPath,
      baseRef: baseRef.trim(),
      targetRef: targetRef.trim(),
      baseCommit,
      targetCommit,
      changes: Object.freeze([...changes]),
    })
    this.currentSnapshot = snapshot
    this.changeEmitter.fire(snapshot)
    return snapshot
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
    this.requestRevision += 1
    this.currentSnapshot = null
    this.changeEmitter.fire(null)
  }

  public dispose(): void {
    this.clear()
    this.changeEmitter.dispose()
  }
}
