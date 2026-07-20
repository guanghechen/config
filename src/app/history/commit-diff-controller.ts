import { Disposable, commands, window } from 'vscode'
import type { IRevisionComparison } from '../../comparison/model'
import { CommitHistorySession } from '../../history/commit-history-session'
import { COMMAND_IDS } from '../../platform/extension-ids'
import { openRevisionDiff } from '../../view/diff/opener'
import { RevisionContentProvider } from '../../view/diff/revision-content-provider'
import { isCommitFileNode } from '../../view/history/tree'

export interface ICommitDiffControllerOptions {
  readonly contentProvider: RevisionContentProvider
  readonly historySession: CommitHistorySession
}

export class CommitDiffController implements Disposable {
  private readonly contentProvider: RevisionContentProvider
  private readonly historySession: CommitHistorySession
  private readonly registration: Disposable

  public constructor(options: ICommitDiffControllerOptions) {
    this.contentProvider = options.contentProvider
    this.historySession = options.historySession
    this.registration = commands.registerCommand(COMMAND_IDS.openCommitFileDiff, (node: unknown) =>
      this.openCommitFileDiff(node),
    )
  }

  public dispose(): void {
    this.registration.dispose()
  }

  private async openCommitFileDiff(value: unknown): Promise<void> {
    const snapshot = this.historySession.snapshot
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
      const message = cause instanceof Error ? cause.message : 'Commit operation failed.'
      await window.showErrorMessage(`VSGit: ${message}`)
    }
  }
}
