import { Disposable, ProgressLocation, commands, window, workspace } from 'vscode'
import { CommitHistorySession } from '../../history/commit-history-session'
import type { ICommitHistorySnapshot } from '../../history/model'
import { COMMAND_IDS } from '../../platform/extension-ids'
import type { IRepositoryResolver } from '../shared/repository-discovery'
import { discoverRepositories, pickRepository } from '../shared/repository-picker'

export interface ICommitHistoryControllerOptions {
  readonly historySession: CommitHistorySession
  readonly repositoryResolver: IRepositoryResolver
}

export class CommitHistoryController implements Disposable {
  private readonly historySession: CommitHistorySession
  private readonly repositoryResolver: IRepositoryResolver
  private readonly registrations: Disposable

  public constructor(options: ICommitHistoryControllerOptions) {
    this.historySession = options.historySession
    this.repositoryResolver = options.repositoryResolver
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
    const repositories = await discoverRepositories(this.repositoryResolver)
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
    const repositoryPath = await pickRepository(this.repositoryResolver)
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
