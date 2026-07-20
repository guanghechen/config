import { Disposable, ProgressLocation, commands, window, type TreeView } from 'vscode'
import type { IComparisonSnapshot } from '../../comparison/model'
import { formatRevisionLabel } from '../../comparison/reference-label'
import { ComparisonSession } from '../../comparison/session'
import { GitClient } from '../../git/git-client'
import { isFileChange } from '../../git/file-change'
import { openRevisionDiff } from '../../view/diff/opener'
import { RevisionContentProvider } from '../../view/diff/revision-content-provider'
import type { IChangeTreeNode, IFileNode } from '../../view/file-change/tree'
import { COMMAND_IDS, CONTEXT_KEYS } from '../../platform/extension-ids'
import { pickRepository } from '../shared/repository-picker'

export interface IComparisonControllerOptions {
  readonly comparisonSession: ComparisonSession
  readonly contentProvider: RevisionContentProvider
  readonly gitClient: GitClient
  readonly treeView: TreeView<IChangeTreeNode>
}

export class ComparisonController implements Disposable {
  private readonly comparisonSession: ComparisonSession
  private readonly contentProvider: RevisionContentProvider
  private readonly gitClient: GitClient
  private readonly registrations: Disposable
  private readonly treeView: TreeView<IChangeTreeNode>

  public constructor(options: IComparisonControllerOptions) {
    this.comparisonSession = options.comparisonSession
    this.contentProvider = options.contentProvider
    this.gitClient = options.gitClient
    this.treeView = options.treeView
    this.registrations = Disposable.from(
      this.comparisonSession.onDidChange(snapshot => this.updateViewState(snapshot)),
      commands.registerCommand(COMMAND_IDS.compareReferences, () => this.compareReferences()),
      commands.registerCommand(COMMAND_IDS.refreshComparison, () =>
        this.runOperation('Refreshing comparison…', () => this.comparisonSession.refresh()),
      ),
      commands.registerCommand(COMMAND_IDS.swapComparisonReferences, () =>
        this.runOperation('Swapping references…', () => this.comparisonSession.swap()),
      ),
      commands.registerCommand(COMMAND_IDS.clearComparison, () => this.comparisonSession.clear()),
      commands.registerCommand(
        COMMAND_IDS.openComparisonDiff,
        (revisionOrNode: unknown, change: unknown) => this.openFileDiff(revisionOrNode, change),
      ),
    )
    this.updateViewState(this.comparisonSession.snapshot)
  }

  public dispose(): void {
    void commands.executeCommand('setContext', CONTEXT_KEYS.hasComparison, false)
    this.registrations.dispose()
  }

  private async compareReferences(): Promise<void> {
    try {
      const repositoryPath = await pickRepository(this.gitClient)
      if (!repositoryPath) return

      const baseRef = await this.promptForReference(
        'Base commit, branch, or tag',
        this.comparisonSession.snapshot?.repositoryPath === repositoryPath
          ? this.comparisonSession.snapshot.baseRef
          : 'HEAD~1',
      )
      if (baseRef === null) return

      const targetRef = await this.promptForReference(
        'Target commit, branch, or tag',
        this.comparisonSession.snapshot?.repositoryPath === repositoryPath
          ? this.comparisonSession.snapshot.targetRef
          : 'HEAD',
      )
      if (targetRef === null) return

      await this.runOperation(`Comparing ${baseRef} with ${targetRef}…`, () =>
        this.comparisonSession.compare(repositoryPath, baseRef, targetRef),
      )
    } catch (cause) {
      await this.showError(cause)
    }
  }

  private async promptForReference(prompt: string, value: string): Promise<string | null> {
    const reference = await window.showInputBox({
      ignoreFocusOut: true,
      prompt,
      title: 'VSGit: Compare References',
      value,
      validateInput: validateReferenceInput,
    })
    return reference === undefined ? null : reference.trim()
  }

  private async runOperation(
    title: string,
    operation: () => Promise<IComparisonSnapshot | null>,
  ): Promise<void> {
    try {
      await window.withProgress(
        { location: ProgressLocation.Notification, title, cancellable: false },
        operation,
      )
    } catch (cause) {
      await this.showError(cause)
    }
  }

  private async openFileDiff(revisionOrNode: unknown, changeValue: unknown): Promise<void> {
    const snapshot = this.comparisonSession.snapshot
    const revision = isFileNode(revisionOrNode) ? snapshot?.revision : revisionOrNode
    const change = isFileNode(revisionOrNode) ? revisionOrNode.change : changeValue
    if (
      !snapshot ||
      typeof revision !== 'number' ||
      revision !== snapshot.revision ||
      !isFileChange(change)
    ) {
      await window.showWarningMessage('VSGit: This comparison is stale. Select the file again.')
      return
    }
    await openRevisionDiff(snapshot, change, this.contentProvider)
  }

  private updateViewState(snapshot: IComparisonSnapshot | null): void {
    void commands.executeCommand('setContext', CONTEXT_KEYS.hasComparison, Boolean(snapshot))
    this.treeView.description = snapshot
      ? `${formatRevisionLabel(snapshot.baseRef)} ↔ ${formatRevisionLabel(snapshot.targetRef)} · ${snapshot.changes.length}`
      : undefined
    this.treeView.message =
      snapshot?.changes.length === 0 ? 'No changes between these references.' : undefined
  }

  private async showError(cause: unknown): Promise<void> {
    const message = cause instanceof Error ? cause.message : 'Comparison failed.'
    await window.showErrorMessage(`VSGit: ${message}`)
  }
}

function isFileNode(value: unknown): value is IFileNode {
  if (!value || typeof value !== 'object') return false
  const node = value as Partial<IFileNode>
  return node.kind === 'file' && isFileChange(node.change)
}

function validateReferenceInput(value: string): string | undefined {
  const reference = value.trim()
  if (!reference) return 'Enter a Git reference.'
  if (reference.length > 1024 || reference.includes('\0')) return 'Git reference is invalid.'
  return undefined
}
