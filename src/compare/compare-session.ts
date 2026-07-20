import { EventEmitter, type Disposable, type Event } from 'vscode'
import type { ICompareSnapshot } from '../contract'
import { GitClient } from '../git/git-client'

export class CompareSession implements Disposable {
  private readonly changeEmitter = new EventEmitter<ICompareSnapshot | null>()
  private operationRevision = 0
  private value: ICompareSnapshot | null = null

  public readonly onDidChange: Event<ICompareSnapshot | null> = this.changeEmitter.event

  public constructor(private readonly gitClient: GitClient) {}

  public get snapshot(): ICompareSnapshot | null {
    return this.value
  }

  public async compare(
    repositoryPath: string,
    baseRef: string,
    targetRef: string,
  ): Promise<ICompareSnapshot | null> {
    const revision = ++this.operationRevision
    const [baseCommit, targetCommit] = await Promise.all([
      this.gitClient.resolveCommit(repositoryPath, baseRef),
      this.gitClient.resolveCommit(repositoryPath, targetRef),
    ])
    const changes = await this.gitClient.listChanges(repositoryPath, baseCommit, targetCommit)
    if (revision !== this.operationRevision) return null

    const snapshot: ICompareSnapshot = Object.freeze({
      revision,
      repositoryPath,
      baseRef: baseRef.trim(),
      targetRef: targetRef.trim(),
      baseCommit,
      targetCommit,
      changes: Object.freeze([...changes]),
    })
    this.value = snapshot
    this.changeEmitter.fire(snapshot)
    return snapshot
  }

  public refresh(): Promise<ICompareSnapshot | null> {
    const snapshot = this.value
    if (!snapshot) return Promise.resolve(null)
    return this.compare(snapshot.repositoryPath, snapshot.baseRef, snapshot.targetRef)
  }

  public swap(): Promise<ICompareSnapshot | null> {
    const snapshot = this.value
    if (!snapshot) return Promise.resolve(null)
    return this.compare(snapshot.repositoryPath, snapshot.targetRef, snapshot.baseRef)
  }

  public clear(): void {
    this.operationRevision += 1
    this.value = null
    this.changeEmitter.fire(null)
  }

  public dispose(): void {
    this.clear()
    this.changeEmitter.dispose()
  }
}
