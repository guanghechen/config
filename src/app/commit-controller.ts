import path from 'node:path'
import { Disposable, ProgressLocation, commands, window, workspace, type TreeView } from 'vscode'
import { CompareSession } from '../compare/compare-session'
import type { IRevisionComparison } from '../compare/model'
import type { IGitCommit } from '../git/commit'
import { GitClient } from '../git/git-client'
import { CommitHistorySession } from '../history/commit-history-session'
import { CommitMarkSession } from '../history/commit-mark-session'
import { orderCommitsForComparison, type IOrderedCommitPair } from '../history/commit-order'
import type { ICommitHistorySnapshot } from '../history/model'
import { isCommitFileNode, isCommitNode, type ICommitTreeNode } from '../view/commit-tree'
import { openRevisionDiff } from '../view/diff-opener'
import { RevisionContentProvider } from '../view/revision-content-provider'
import { discoverRepositories, pickRepository } from './repository-picker'

const COMMAND = {
  clearMarks: 'vsgit.clearCommitMarks',
  compareMarked: 'vsgit.compareMarkedCommits',
  compareToHead: 'vsgit.compareCommitToHead',
  compareWithMarked: 'vsgit.compareWithMarkedCommit',
  loadMore: 'vsgit.loadMoreCommits',
  mark: 'vsgit.markCommit',
  openFileDiff: 'vsgit.openCommitFileDiff',
  refresh: 'vsgit.refreshCommits',
  selectRepository: 'vsgit.selectRepository',
  unmark: 'vsgit.unmarkCommit',
} as const

export interface ICommitControllerOptions {
  readonly compareSession: CompareSession
  readonly contentProvider: RevisionContentProvider
  readonly gitClient: GitClient
  readonly marks: CommitMarkSession
  readonly session: CommitHistorySession
  readonly treeView: TreeView<ICommitTreeNode>
}

export class CommitController implements Disposable {
  private readonly compareSession: CompareSession
  private readonly contentProvider: RevisionContentProvider
  private readonly gitClient: GitClient
  private readonly marks: CommitMarkSession
  private readonly registrations: Disposable
  private readonly session: CommitHistorySession
  private readonly treeView: TreeView<ICommitTreeNode>

  public constructor(options: ICommitControllerOptions) {
    this.compareSession = options.compareSession
    this.contentProvider = options.contentProvider
    this.gitClient = options.gitClient
    this.marks = options.marks
    this.session = options.session
    this.treeView = options.treeView
    this.registrations = Disposable.from(
      this.session.onDidChange(snapshot => this.updateViewState(snapshot)),
      this.marks.onDidChange(() => this.updateMarkState()),
      commands.registerCommand(COMMAND.clearMarks, () => this.marks.clear()),
      commands.registerCommand(COMMAND.compareMarked, () => this.compareMarkedCommits()),
      commands.registerCommand(COMMAND.compareToHead, (node: unknown) =>
        this.compareCommitToHead(node),
      ),
      commands.registerCommand(COMMAND.compareWithMarked, (node: unknown) =>
        this.compareWithMarkedCommit(node),
      ),
      commands.registerCommand(COMMAND.refresh, () => this.refresh()),
      commands.registerCommand(COMMAND.selectRepository, () => this.selectRepository()),
      commands.registerCommand(COMMAND.loadMore, () =>
        this.runOperation('Loading more commits…', () => this.session.loadMore()),
      ),
      commands.registerCommand(COMMAND.openFileDiff, (node: unknown) =>
        this.openCommitFileDiff(node),
      ),
      commands.registerCommand(COMMAND.mark, (node: unknown) => this.markCommit(node)),
      commands.registerCommand(COMMAND.unmark, (node: unknown) => this.unmarkCommit(node)),
      workspace.onDidChangeWorkspaceFolders(() => void this.synchronizeRepository()),
    )
    this.updateViewState(this.session.snapshot)
  }

  public async initialize(): Promise<void> {
    await this.synchronizeRepository()
  }

  public dispose(): void {
    for (const context of [
      'vsgit.canCompareMarkedCommits',
      'vsgit.hasCommitMarks',
      'vsgit.hasOneCommitMark',
    ]) {
      void commands.executeCommand('setContext', context, false)
    }
    this.registrations.dispose()
  }

  private async synchronizeRepository(): Promise<void> {
    const repositories = await discoverRepositories(this.gitClient)
    const currentRepository = this.session.snapshot?.repositoryPath
    if (currentRepository && repositories.includes(currentRepository)) {
      await this.runOperation('Refreshing commits…', () => this.session.refresh())
      return
    }

    const repositoryPath = repositories[0]
    if (!repositoryPath) {
      this.session.clear()
      return
    }
    await this.runOperation('Loading commits…', () => this.session.load(repositoryPath))
  }

  private async refresh(): Promise<void> {
    if (!this.session.snapshot) {
      await this.synchronizeRepository()
      return
    }
    await this.runOperation('Refreshing commits…', () => this.session.refresh())
  }

  private async selectRepository(): Promise<void> {
    const repositoryPath = await pickRepository(this.gitClient)
    if (!repositoryPath) return
    await this.runOperation('Loading commits…', () => this.session.load(repositoryPath))
  }

  private async compareMarkedCommits(): Promise<void> {
    const pair = this.getMarkedCommitPair()
    const snapshot = this.session.snapshot
    if (!pair || !snapshot) {
      await window.showWarningMessage('VSGit: Mark exactly two current commits to compare.')
      return
    }

    await this.compareCommits(
      snapshot.repositoryPath,
      pair.base.hash,
      pair.target.hash,
      `Comparing ${pair.base.shortHash} with ${pair.target.shortHash}…`,
    )
  }

  private async compareWithMarkedCommit(value: unknown): Promise<void> {
    const snapshot = this.session.snapshot
    const commit = this.getCurrentCommit(value)
    const markedHash = this.marks.markedHashes[0]
    const marked = snapshot?.commits.find(candidate => candidate.hash === markedHash)
    const pair =
      snapshot && commit && marked && this.marks.count === 1
        ? orderCommitsForComparison(snapshot.commits, [marked, commit])
        : null
    if (!snapshot || !pair) {
      await window.showWarningMessage(
        'VSGit: Mark one commit, then choose a different current commit to compare.',
      )
      return
    }

    await this.compareCommits(
      snapshot.repositoryPath,
      pair.base.hash,
      pair.target.hash,
      `Comparing ${pair.base.shortHash} with ${pair.target.shortHash}…`,
    )
  }

  private async compareCommitToHead(value: unknown): Promise<void> {
    const snapshot = this.session.snapshot
    const commit = this.getCurrentCommit(value)
    if (!snapshot || !commit) {
      await this.showStaleCommitWarning()
      return
    }

    let headCommit: string
    try {
      headCommit = await this.gitClient.resolveCommit(snapshot.repositoryPath, 'HEAD')
    } catch (cause) {
      await this.showError(cause)
      return
    }
    if (this.session.snapshot?.revision !== snapshot.revision) {
      await this.showStaleCommitWarning()
      return
    }
    if (headCommit === commit.hash) {
      await window.showInformationMessage('VSGit: This commit is already HEAD.')
      return
    }

    await this.compareCommits(
      snapshot.repositoryPath,
      commit.hash,
      headCommit,
      `Comparing ${commit.shortHash} with HEAD…`,
    )
  }

  private async markCommit(value: unknown): Promise<void> {
    const snapshot = this.session.snapshot
    const commit = this.getCurrentCommit(value)
    if (!snapshot || !commit) {
      await this.showStaleCommitWarning()
      return
    }

    const result = this.marks.mark(snapshot.repositoryPath, commit.hash)
    if (result === 'full') {
      await window.showWarningMessage(
        'VSGit: Two commits are already marked. Unmark one before marking another.',
      )
    } else if (result === 'stale') {
      await this.showStaleCommitWarning()
    }
  }

  private async unmarkCommit(value: unknown): Promise<void> {
    const snapshot = this.session.snapshot
    const commit = this.getCurrentCommit(value)
    if (!snapshot || !commit) {
      await this.showStaleCommitWarning()
      return
    }
    this.marks.unmark(snapshot.repositoryPath, commit.hash)
  }

  private async openCommitFileDiff(value: unknown): Promise<void> {
    const snapshot = this.session.snapshot
    if (
      !snapshot ||
      !isCommitFileNode(value) ||
      value.context.historyRevision !== snapshot.revision ||
      value.context.repositoryPath !== snapshot.repositoryPath
    ) {
      await window.showWarningMessage('VSGit: This commit history is stale. Select the file again.')
      return
    }

    const { commit, parentCommit } = value.context
    const comparison: IRevisionComparison = {
      repositoryPath: snapshot.repositoryPath,
      baseRef: parentCommit ? parentCommit.slice(0, commit.shortHash.length) : 'Empty tree',
      targetRef: commit.shortHash,
      baseCommit: parentCommit ?? commit.hash,
      targetCommit: commit.hash,
    }
    try {
      await openRevisionDiff(comparison, value.change, this.contentProvider)
    } catch (cause) {
      await this.showError(cause)
    }
  }

  private async runOperation(
    title: string,
    operation: () => Promise<ICommitHistorySnapshot | null>,
  ): Promise<void> {
    try {
      await window.withProgress(
        { location: ProgressLocation.Window, title, cancellable: false },
        operation,
      )
    } catch (cause) {
      await this.showError(cause)
    }
  }

  private updateViewState(snapshot: ICommitHistorySnapshot | null): void {
    this.marks.reconcile(snapshot)
    void commands.executeCommand('setContext', 'vsgit.hasCommitHistory', Boolean(snapshot))
    this.updateViewDescription(snapshot)
    this.treeView.message = snapshot
      ? snapshot.commits.length === 0
        ? 'No commits found in this repository.'
        : undefined
      : 'Open a Git repository to browse commits.'
    this.updateMarkContext()
  }

  private getMarkedCommitPair(): IOrderedCommitPair | null {
    const snapshot = this.session.snapshot
    if (!snapshot || this.marks.count !== 2) return null

    const marked: IGitCommit[] = []
    for (const hash of this.marks.markedHashes) {
      const commit = snapshot.commits.find(candidate => candidate.hash === hash)
      if (!commit) return null
      marked.push(commit)
    }
    return orderCommitsForComparison(snapshot.commits, marked)
  }

  private getCurrentCommit(value: unknown): IGitCommit | null {
    const snapshot = this.session.snapshot
    if (
      !snapshot ||
      !isCommitNode(value) ||
      value.context.historyRevision !== snapshot.revision ||
      value.context.repositoryPath !== snapshot.repositoryPath
    ) {
      return null
    }
    return snapshot.commits.find(commit => commit.hash === value.context.commit.hash) ?? null
  }

  private updateMarkState(): void {
    this.updateMarkContext()
    this.updateViewDescription(this.session.snapshot)
  }

  private updateMarkContext(): void {
    const count = this.marks.count
    void commands.executeCommand('setContext', 'vsgit.hasCommitMarks', count > 0)
    void commands.executeCommand('setContext', 'vsgit.hasOneCommitMark', count === 1)
    void commands.executeCommand(
      'setContext',
      'vsgit.canCompareMarkedCommits',
      Boolean(this.getMarkedCommitPair()),
    )
  }

  private updateViewDescription(snapshot: ICommitHistorySnapshot | null): void {
    if (!snapshot) {
      this.treeView.description = undefined
      return
    }
    const markDescription = this.marks.count > 0 ? ` · ${this.marks.count} marked` : ''
    this.treeView.description = `${path.basename(snapshot.repositoryPath)} · ${snapshot.commits.length}${snapshot.hasMore ? '+' : ''}${markDescription}`
  }

  private async compareCommits(
    repositoryPath: string,
    baseRef: string,
    targetRef: string,
    title: string,
  ): Promise<void> {
    try {
      const comparison = await window.withProgress(
        { location: ProgressLocation.Notification, title, cancellable: false },
        () => this.compareSession.compare(repositoryPath, baseRef, targetRef),
      )
      if (comparison) await commands.executeCommand('vsgit.changes.focus')
    } catch (cause) {
      await this.showError(cause)
    }
  }

  private async showStaleCommitWarning(): Promise<void> {
    await window.showWarningMessage('VSGit: This commit history is stale. Select the commit again.')
  }

  private async showError(cause: unknown): Promise<void> {
    const message = cause instanceof Error ? cause.message : 'Commit operation failed.'
    await window.showErrorMessage(`VSGit: ${message}`)
  }
}
