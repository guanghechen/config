import path from 'node:path'
import { Uri } from 'vscode'
import type { FileChangeKind } from '../../git/file-change'
import { createFileChangeQuery } from './decoration'

export function createRepositoryResourceUri(
  repositoryPath: string,
  relativePath: string,
  changeKind?: FileChangeKind,
): Uri {
  const resource = Uri.file(path.join(repositoryPath, relativePath))
  return changeKind ? resource.with({ query: createFileChangeQuery(changeKind) }) : resource
}
