import { MarkdownString } from 'vscode'
import type { FileChangeKind, IFileChange } from '../git/file-change'

export function createFileChangeDescription(change: IFileChange): string {
  if (change.kind === 'renamed' || change.kind === 'copied') {
    return `${change.status} · ${change.previousPath ?? ''}`
  }
  return change.status
}

export function createFileChangeTooltip(change: IFileChange): MarkdownString {
  const tooltip = new MarkdownString(undefined, false)
  tooltip.appendText(`${change.status} `)
  if (change.previousPath && change.currentPath && change.previousPath !== change.currentPath) {
    tooltip.appendText(`${change.previousPath} → ${change.currentPath}`)
  } else {
    tooltip.appendText(change.currentPath ?? change.previousPath ?? '')
  }
  return tooltip
}

export function resolveFileChangeIcon(kind: FileChangeKind): string {
  switch (kind) {
    case 'added':
      return 'diff-added'
    case 'deleted':
      return 'diff-removed'
    case 'renamed':
    case 'copied':
      return 'diff-renamed'
    case 'modified':
    case 'typeChanged':
    case 'unmerged':
    case 'unknown':
      return 'diff-modified'
  }
}
