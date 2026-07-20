import { commands } from 'vscode'
import type { ICompareSnapshot } from '../compare/model'
import { resolveDisplayPath, type IFileChange } from '../git/file-change'
import { RevisionContentProvider } from './revision-content-provider'

export async function openRevisionDiff(
  snapshot: ICompareSnapshot,
  change: IFileChange,
  contentProvider: RevisionContentProvider,
): Promise<void> {
  const displayPath = resolveDisplayPath(change)
  const previousPath = change.previousPath ?? displayPath
  const currentPath = change.currentPath ?? displayPath
  const leftUri = contentProvider.createUri(
    snapshot.repositoryPath,
    snapshot.baseCommit,
    previousPath,
    'base',
    change.previousPath === null,
  )
  const rightUri = contentProvider.createUri(
    snapshot.repositoryPath,
    snapshot.targetCommit,
    currentPath,
    'target',
    change.currentPath === null,
  )
  await commands.executeCommand(
    'vscode.diff',
    leftUri,
    rightUri,
    createDiffTitle(snapshot, change),
    { preview: true },
  )
}

function createDiffTitle(snapshot: ICompareSnapshot, change: IFileChange): string {
  const pathLabel =
    change.previousPath && change.currentPath && change.previousPath !== change.currentPath
      ? `${change.previousPath} → ${change.currentPath}`
      : resolveDisplayPath(change)
  return `${pathLabel} (${shorten(snapshot.baseRef)} ↔ ${shorten(snapshot.targetRef)})`
}

function shorten(value: string): string {
  return value.length > 24 ? `${value.slice(0, 21)}…` : value
}
