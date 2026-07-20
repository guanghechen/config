import { MarkdownString } from 'vscode'
import type { IFileChange } from '../git/file-change'

export function createFileChangeDescription(change: IFileChange): string | undefined {
  if (change.kind === 'renamed' || change.kind === 'copied') {
    return change.previousPath ? `← ${change.previousPath}` : undefined
  }
  return undefined
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
