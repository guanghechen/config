import path from 'node:path'
import { Disposable, commands, type TreeView } from 'vscode'
import type { CommitHistorySession } from '../../history/commit-history-session'
import type { CommitMarkSession } from '../../history/commit-mark-session'
import type { ICommitHistorySnapshot } from '../../history/model'
import { CONTEXT_KEYS } from '../../platform/extension-ids'
import { formatCommitSearchQuery } from '../../view/history/search-presentation'
import type { ICommitTreeNode } from '../../view/history/tree'

export interface ICommitViewControllerOptions {
  readonly historySession: CommitHistorySession
  readonly markSession: CommitMarkSession
  readonly treeView: TreeView<ICommitTreeNode>
}

export class CommitViewController implements Disposable {
  private readonly historySession: CommitHistorySession
  private readonly markSession: CommitMarkSession
  private readonly subscriptions: Disposable
  private readonly treeView: TreeView<ICommitTreeNode>

  public constructor(options: ICommitViewControllerOptions) {
    this.historySession = options.historySession
    this.markSession = options.markSession
    this.treeView = options.treeView
    this.subscriptions = Disposable.from(
      this.historySession.onDidChange(snapshot => this.update(snapshot)),
      this.markSession.onDidChange(() => this.update(this.historySession.snapshot)),
    )
    this.update(this.historySession.snapshot)
  }

  public dispose(): void {
    void commands.executeCommand('setContext', CONTEXT_KEYS.hasCommitHistory, false)
    void commands.executeCommand('setContext', CONTEXT_KEYS.hasCommitSearch, false)
    this.subscriptions.dispose()
  }

  private update(snapshot: ICommitHistorySnapshot | null): void {
    void commands.executeCommand('setContext', CONTEXT_KEYS.hasCommitHistory, Boolean(snapshot))
    void commands.executeCommand(
      'setContext',
      CONTEXT_KEYS.hasCommitSearch,
      Boolean(snapshot?.searchQuery),
    )
    this.treeView.description = createViewDescription(snapshot, this.markSession.count)
    this.treeView.message = snapshot
      ? snapshot.commits.length === 0
        ? snapshot.searchQuery
          ? 'No commits match the current search.'
          : 'No commits found in this repository.'
        : undefined
      : 'Open a Git repository to browse commits.'
  }
}

function createViewDescription(
  snapshot: ICommitHistorySnapshot | null,
  markCount: number,
): string | undefined {
  if (!snapshot) return undefined
  const markDescription = markCount > 0 ? ` · ${markCount} marked` : ''
  const count = `${snapshot.commits.length}${snapshot.hasMore ? '+' : ''}`
  const searchDescription = snapshot.searchQuery
    ? ` · Search: ${formatCommitSearchQuery(snapshot.searchQuery)}`
    : ''
  return `${path.basename(snapshot.repositoryPath)} · ${count}${searchDescription}${markDescription}`
}
