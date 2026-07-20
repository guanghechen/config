import path from 'node:path'
import { Disposable, ProgressLocation, commands, window, workspace, type TreeView } from 'vscode'
import { CompareSession } from '../compare/compare-session'
import type { IRevisionComparison } from '../compare/model'
import { GitClient } from '../git/git-client'
import { CommitHistorySession } from '../history/commit-history-session'
import { orderCommitsForComparison, type IOrderedCommitPair } from '../history/commit-order'
import type { ICommitHistorySnapshot } from '../history/model'
import { isCommitFileNode, isCommitNode, type ICommitTreeNode } from '../view/commit-tree'
import { openRevisionDiff } from '../view/diff-opener'
import { RevisionContentProvider } from '../view/revision-content-provider'
import { discoverRepositories, pickRepository } from './repository-picker'

const COMMAND = {
  compareSelected: 'vsgit.compareSelectedCommits',
  loadMore: 'vsgit.loadMoreCommits',
  openFileDiff: 'vsgit.openCommitFileDiff',
  refresh: 'vsgit.refreshCommits',
  selectRepository: 'vsgit.selectRepository',
} as const

export interface ICommitControllerOptions {
  readonly compareSession: CompareSession
  readonly contentProvider: RevisionContentProvider
  readonly gitClient: GitClient
  readonly session: CommitHistorySession
  readonly treeView: TreeView<ICommitTreeNode>
}

export class CommitController implements Disposable {
  private readonly compareSession: CompareSession
  private readonly contentProvider: RevisionContentProvider
  private readonly gitClient: GitClient
  private readonly registrations: Disposable
  private readonly session: CommitHistorySession
  private readonly treeView: TreeView<ICommitTreeNode>

  public constructor(options: ICommitControllerOptions) {
    this.compareSession = options.compareSession
    this.contentProvider = options.contentProvider
    this.gitClient = options.gitClient
    this.session = options.session
    this.treeView = options.treeView
    this.registrations = Disposable.from(
      this.session.onDidChange(snapshot => this.updateViewState(snapshot)),
      this.treeView.onDidChangeSelection(() => this.updateSelectionContext()),
      commands.registerCommand(COMMAND.compareSelected, () => this.compareSelectedCommits()),
      commands.registerCommand(COMMAND.refresh, () => this.refresh()),
      commands.registerCommand(COMMAND.selectRepository, () => this.selectRepository()),
      commands.registerCommand(COMMAND.loadMore, () =>
        this.runOperation('Loading more commits…', () => this.session.loadMore()),
      ),
      commands.registerCommand(COMMAND.openFileDiff, (node: unknown) =>
        this.openCommitFileDiff(node),
      ),
      workspace.onDidChangeWorkspaceFolders(() => void this.synchronizeRepository()),
    )
    this.updateViewState(this.session.snapshot)
  }

  public async initialize(): Promise<void> {
    await this.synchronizeRepository()
  }

  public dispose(): void {
    void commands.executeCommand('setContext', 'vsgit.canCompareSelectedCommits', false)
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

  private async compareSelectedCommits(): Promise<void> {
    const pair = this.getSelectedCommitPair()
    const snapshot = this.session.snapshot
    if (!pair || !snapshot) {
      await window.showWarningMessage('VSGit: Select exactly two current commits to compare.')
      return
    }

    try {
      const comparison = await window.withProgress(
        {
          location: ProgressLocation.Notification,
          title: `Comparing ${pair.base.shortHash} with ${pair.target.shortHash}…`,
          cancellable: false,
        },
        () =>
          this.compareSession.compare(snapshot.repositoryPath, pair.base.hash, pair.target.hash),
      )
      if (comparison) await commands.executeCommand('vsgit.changes.focus')
    } catch (cause) {
      await this.showError(cause)
    }
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
    void commands.executeCommand('setContext', 'vsgit.hasCommitHistory', Boolean(snapshot))
    this.treeView.description = snapshot
      ? `${path.basename(snapshot.repositoryPath)} · ${snapshot.commits.length}${snapshot.hasMore ? '+' : ''}`
      : undefined
    this.treeView.message = snapshot
      ? snapshot.commits.length === 0
        ? 'No commits found in this repository.'
        : undefined
      : 'Open a Git repository to browse commits.'
    this.updateSelectionContext()
  }

  private getSelectedCommitPair(): IOrderedCommitPair | null {
    const snapshot = this.session.snapshot
    const selection = this.treeView.selection
    const left = selection[0]
    const right = selection[1]
    if (
      !snapshot ||
      selection.length !== 2 ||
      !isCommitNode(left) ||
      !isCommitNode(right) ||
      left.context.historyRevision !== snapshot.revision ||
      right.context.historyRevision !== snapshot.revision ||
      left.context.repositoryPath !== snapshot.repositoryPath ||
      right.context.repositoryPath !== snapshot.repositoryPath
    ) {
      return null
    }
    return orderCommitsForComparison(snapshot.commits, [left.context.commit, right.context.commit])
  }

  private updateSelectionContext(): void {
    void commands.executeCommand(
      'setContext',
      'vsgit.canCompareSelectedCommits',
      Boolean(this.getSelectedCommitPair()),
    )
  }

  private async showError(cause: unknown): Promise<void> {
    const message = cause instanceof Error ? cause.message : 'Commit operation failed.'
    await window.showErrorMessage(`VSGit: ${message}`)
  }
}
