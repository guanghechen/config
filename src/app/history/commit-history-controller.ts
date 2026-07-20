import { Disposable, ProgressLocation, commands, window, workspace } from 'vscode'
import { GitClient } from '../../git/git-client'
import { CommitHistorySession } from '../../history/commit-history-session'
import type { ICommitHistorySnapshot } from '../../history/model'
import { COMMAND_IDS } from '../../platform/extension-ids'
import { discoverRepositories, pickRepository } from '../shared/repository-picker'

export interface ICommitHistoryControllerOptions {
  readonly gitClient: GitClient
  readonly historySession: CommitHistorySession
}

export class CommitHistoryController implements Disposable {
  private readonly gitClient: GitClient
  private readonly historySession: CommitHistorySession
  private readonly registrations: Disposable

  public constructor(options: ICommitHistoryControllerOptions) {
    this.gitClient = options.gitClient
    this.historySession = options.historySession
    this.registrations = Disposable.from(
      commands.registerCommand(COMMAND_IDS.refreshCommits, () => this.refresh()),
      commands.registerCommand(COMMAND_IDS.selectRepository, () => this.selectRepository()),
      commands.registerCommand(COMMAND_IDS.loadMoreCommits, () =>
        this.runOperation('Loading more commits…', () => this.historySession.loadMore()),
      ),
      workspace.onDidChangeWorkspaceFolders(() => void this.synchronizeRepository()),
    )
  }

  public async initialize(): Promise<void> {
    await this.synchronizeRepository()
  }

  public dispose(): void {
    this.registrations.dispose()
  }

  private async synchronizeRepository(): Promise<void> {
    const repositories = await discoverRepositories(this.gitClient)
    const currentRepository = this.historySession.snapshot?.repositoryPath
    if (currentRepository && repositories.includes(currentRepository)) {
      await this.runOperation('Refreshing commits…', () => this.historySession.refresh())
      return
    }

    const repositoryPath = repositories[0]
    if (!repositoryPath) {
      this.historySession.clear()
      return
    }
    await this.runOperation('Loading commits…', () => this.historySession.load(repositoryPath))
  }

  private async refresh(): Promise<void> {
    if (!this.historySession.snapshot) {
      await this.synchronizeRepository()
      return
    }
    await this.runOperation('Refreshing commits…', () => this.historySession.refresh())
  }

  private async selectRepository(): Promise<void> {
    const repositoryPath = await pickRepository(this.gitClient)
    if (!repositoryPath) return
    await this.runOperation('Loading commits…', () => this.historySession.load(repositoryPath))
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
      const message = cause instanceof Error ? cause.message : 'Commit operation failed.'
      await window.showErrorMessage(`VSGit: ${message}`)
    }
  }
}
