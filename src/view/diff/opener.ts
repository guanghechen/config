import { commands } from 'vscode'
import type { IRevisionComparison } from '../../comparison/model'
import { formatRevisionLabel } from '../../comparison/reference-label'
import { resolveDisplayPath, type IFileChange } from '../../git/file-change'
import { RevisionContentProvider } from './revision-content-provider'

export async function openRevisionDiff(
  comparison: IRevisionComparison,
  change: IFileChange,
  contentProvider: RevisionContentProvider,
): Promise<void> {
  const displayPath = resolveDisplayPath(change)
  const previousPath = change.previousPath ?? displayPath
  const currentPath = change.currentPath ?? displayPath
  const leftUri = contentProvider.createUri(
    comparison.repositoryPath,
    comparison.baseCommit,
    previousPath,
    'base',
    change.previousPath === null,
  )
  const rightUri = contentProvider.createUri(
    comparison.repositoryPath,
    comparison.targetCommit,
    currentPath,
    'target',
    change.currentPath === null,
  )
  await commands.executeCommand(
    'vscode.diff',
    leftUri,
    rightUri,
    createDiffTitle(comparison, change),
    { preview: true },
  )
}

function createDiffTitle(comparison: IRevisionComparison, change: IFileChange): string {
  const pathLabel =
    change.previousPath && change.currentPath && change.previousPath !== change.currentPath
      ? `${change.previousPath} → ${change.currentPath}`
      : resolveDisplayPath(change)
  return `${pathLabel} (${formatRevisionLabel(comparison.baseRef)} ↔ ${formatRevisionLabel(comparison.targetRef)})`
}
