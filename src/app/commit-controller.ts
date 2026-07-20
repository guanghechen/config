import path from 'node:path'
import { Disposable, ProgressLocation, commands, window, workspace, type TreeView } from 'vscode'
import type { IRevisionComparison } from '../compare/model'
import { GitClient } from '../git/git-client'
import { CommitHistorySession } from '../history/commit-history-session'
import type { ICommitHistorySnapshot } from '../history/model'
import { isCommitFileNode, type ICommitTreeNode } from '../view/commit-tree'
import { openRevisionDiff } from '../view/diff-opener'
import { RevisionContentProvider } from '../view/revision-content-provider'
import { discoverRepositories, pickRepository } from './repository-picker'

const COMMAND = {
  loadMore: 'vsgit.loadMoreCommits',
  openFileDiff: 'vsgit.openCommitFileDiff',
  refresh: 'vsgit.refreshCommits',
  selectRepository: 'vsgit.selectRepository',
} as const

export interface ICommitControllerOptions {
  readonly contentProvider: RevisionContentProvider
  readonly gitClient: GitClient
  readonly session: CommitHistorySession
  readonly treeView: TreeView<ICommitTreeNode>
}

export class CommitController implements Disposable {
  private readonly contentProvider: RevisionContentProvider
  private readonly gitClient: GitClient
  private readonly registrations: Disposable
  private readonly session: CommitHistorySession
  private readonly treeView: TreeView<ICommitTreeNode>

  public constructor(options: ICommitControllerOptions) {
    this.contentProvider = options.contentProvider
    this.gitClient = options.gitClient
    this.session = options.session
    this.treeView = options.treeView
    this.registrations = Disposable.from(
      this.session.onDidChange(snapshot => this.updateViewState(snapshot)),
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
  }

  private async showError(cause: unknown): Promise<void> {
    const message = cause instanceof Error ? cause.message : 'Commit operation failed.'
    await window.showErrorMessage(`VSGit: ${message}`)
  }
}
