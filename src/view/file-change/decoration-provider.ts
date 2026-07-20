import {
  FileDecoration,
  ThemeColor,
  type FileDecorationProvider,
  type ProviderResult,
  type Uri,
} from 'vscode'
import { parseFileChangeQuery, resolveFileChangeDecoration } from './decoration'

export class GitFileDecorationProvider implements FileDecorationProvider {
  public provideFileDecoration(uri: Uri): ProviderResult<FileDecoration> {
    const kind = parseFileChangeQuery(uri.query)
    if (!kind) return undefined

    const decoration = resolveFileChangeDecoration(kind)
    return new FileDecoration(
      decoration.badge,
      `Git: ${decoration.label}`,
      new ThemeColor(decoration.colorId),
    )
  }
}
