import { Disposable, ProgressLocation, commands, window } from 'vscode'
import type { IRevisionComparison } from '../../comparison/model'
import type { ComparisonSession } from '../../comparison/session'
import type { IGitCommit } from '../../git/commit'
import type { CommitHistorySession } from '../../history/commit-history-session'
import type { CommitMarkSession } from '../../history/commit-mark-session'
import { orderCommitsForComparison, type IOrderedCommitPair } from '../../history/commit-order'
import { COMMAND_IDS, CONTEXT_KEYS } from '../../platform/extension-ids'
import { isCommitNode } from '../../view/history/tree'

export interface ICommitComparisonControllerOptions {
  readonly comparisonSession: ComparisonSession
  readonly historySession: CommitHistorySession
  readonly markSession: CommitMarkSession
}

export class CommitComparisonController implements Disposable {
  private readonly comparisonSession: ComparisonSession
  private readonly historySession: CommitHistorySession
  private readonly markSession: CommitMarkSession
  private readonly registrations: Disposable

  public constructor(options: ICommitComparisonControllerOptions) {
    this.comparisonSession = options.comparisonSession
    this.historySession = options.historySession
    this.markSession = options.markSession
    this.registrations = Disposable.from(
      this.historySession.onDidChange(snapshot => {
        this.markSession.reconcile(snapshot)
        this.updateContextKeys()
      }),
      this.markSession.onDidChange(() => this.updateContextKeys()),
      commands.registerCommand(COMMAND_IDS.clearCommitMarks, () => this.markSession.clear()),
      commands.registerCommand(COMMAND_IDS.compareMarkedCommits, () => this.compareMarkedCommits()),
      commands.registerCommand(COMMAND_IDS.compareCommitToHead, (node: unknown) =>
        this.compareCommitToHead(node),
      ),
      commands.registerCommand(COMMAND_IDS.compareWithMarkedCommit, (node: unknown) =>
        this.compareWithMarkedCommit(node),
      ),
      commands.registerCommand(COMMAND_IDS.markCommit, (node: unknown) => this.markCommit(node)),
      commands.registerCommand(COMMAND_IDS.unmarkCommit, (node: unknown) =>
        this.unmarkCommit(node),
      ),
    )
    this.markSession.reconcile(this.historySession.snapshot)
    this.updateContextKeys()
  }

  public dispose(): void {
    for (const contextKey of [
      CONTEXT_KEYS.canCompareMarkedCommits,
      CONTEXT_KEYS.hasCommitMarks,
      CONTEXT_KEYS.hasOneCommitMark,
    ]) {
      void commands.executeCommand('setContext', contextKey, false)
    }
    this.registrations.dispose()
  }

  private async compareMarkedCommits(): Promise<void> {
    const pair = this.getMarkedCommitPair()
    const snapshot = this.historySession.snapshot
    if (!pair || !snapshot) {
      await window.showWarningMessage('VSGit: Mark exactly two current commits to compare.')
      return
    }

    await this.compareCommits(
      createResolvedComparison(snapshot.repositoryPath, pair.base.hash, pair.target.hash),
      `Comparing ${pair.base.shortHash} with ${pair.target.shortHash}…`,
    )
  }

  private async compareWithMarkedCommit(value: unknown): Promise<void> {
    const snapshot = this.historySession.snapshot
    const commit = this.getCurrentCommit(value)
    const markedHash = this.markSession.markedHashes[0]
    const marked = snapshot?.commits.find(candidate => candidate.hash === markedHash)
    const pair =
      snapshot && commit && marked && this.markSession.count === 1
        ? orderCommitsForComparison(snapshot.commits, [marked, commit])
        : null
    if (!snapshot || !pair) {
      await window.showWarningMessage(
        'VSGit: Mark one commit, then choose a different current commit to compare.',
      )
      return
    }

    await this.compareCommits(
      createResolvedComparison(snapshot.repositoryPath, pair.base.hash, pair.target.hash),
      `Comparing ${pair.base.shortHash} with ${pair.target.shortHash}…`,
    )
  }

  private async compareCommitToHead(value: unknown): Promise<void> {
    const snapshot = this.historySession.snapshot
    const commit = this.getCurrentCommit(value)
    if (!snapshot || !commit) {
      await this.showStaleCommitWarning()
      return
    }

    const headCommit = snapshot.headCommit
    if (!headCommit) {
      await this.showStaleCommitWarning()
      return
    }
    if (headCommit === commit.hash) {
      await window.showInformationMessage('VSGit: This commit is already HEAD.')
      return
    }

    await this.compareCommits(
      createResolvedComparison(snapshot.repositoryPath, commit.hash, headCommit, 'HEAD'),
      `Comparing ${commit.shortHash} with HEAD…`,
    )
  }

  private async markCommit(value: unknown): Promise<void> {
    const snapshot = this.historySession.snapshot
    const commit = this.getCurrentCommit(value)
    if (!snapshot || !commit) {
      await this.showStaleCommitWarning()
      return
    }

    const result = this.markSession.mark(snapshot.repositoryPath, commit.hash)
    if (result === 'full') {
      await window.showWarningMessage(
        'VSGit: Two commits are already marked. Unmark one before marking another.',
      )
    } else if (result === 'stale') {
      await this.showStaleCommitWarning()
    }
  }

  private async unmarkCommit(value: unknown): Promise<void> {
    const snapshot = this.historySession.snapshot
    const commit = this.getCurrentCommit(value)
    if (!snapshot || !commit) {
      await this.showStaleCommitWarning()
      return
    }
    this.markSession.unmark(snapshot.repositoryPath, commit.hash)
  }

  private getMarkedCommitPair(): IOrderedCommitPair | null {
    const snapshot = this.historySession.snapshot
    if (!snapshot || this.markSession.count !== 2) return null

    const marked: IGitCommit[] = []
    for (const hash of this.markSession.markedHashes) {
      const commit = snapshot.commits.find(candidate => candidate.hash === hash)
      if (!commit) return null
      marked.push(commit)
    }
    return orderCommitsForComparison(snapshot.commits, marked)
  }

  private getCurrentCommit(value: unknown): IGitCommit | null {
    const snapshot = this.historySession.snapshot
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

  private updateContextKeys(): void {
    const markCount = this.markSession.count
    void commands.executeCommand('setContext', CONTEXT_KEYS.hasCommitMarks, markCount > 0)
    void commands.executeCommand('setContext', CONTEXT_KEYS.hasOneCommitMark, markCount === 1)
    void commands.executeCommand(
      'setContext',
      CONTEXT_KEYS.canCompareMarkedCommits,
      Boolean(this.getMarkedCommitPair()),
    )
  }

  private async compareCommits(comparison: IRevisionComparison, title: string): Promise<void> {
    try {
      const snapshot = await window.withProgress(
        { location: ProgressLocation.Notification, title, cancellable: false },
        () => this.comparisonSession.compareResolved(comparison),
      )
      if (snapshot) await commands.executeCommand(COMMAND_IDS.focusComparison)
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

function createResolvedComparison(
  repositoryPath: string,
  baseCommit: string,
  targetCommit: string,
  targetRef = targetCommit,
): IRevisionComparison {
  return {
    repositoryPath,
    baseRef: baseCommit,
    targetRef,
    baseCommit,
    targetCommit,
  }
}
