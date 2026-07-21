import path from 'node:path'
import { CancellationTokenSource, window, workspace } from 'vscode'
import { resolveRepositoryCandidates, type IRepositoryResolver } from './repository-discovery'

export type RepositorySelectionResult =
  | { readonly kind: 'selected'; readonly repositoryPath: string }
  | { readonly kind: 'cancelled' }
  | { readonly kind: 'unavailable' }

export async function pickRepository(
  repositoryResolver: IRepositoryResolver,
): Promise<string | null> {
  const result = await selectRepository(repositoryResolver)
  if (result.kind === 'unavailable') {
    await window.showErrorMessage('VSGit: Open a Git repository to continue.')
  }
  return result.kind === 'selected' ? result.repositoryPath : null
}

export async function selectRepository(
  repositoryResolver: IRepositoryResolver,
  signal?: AbortSignal,
): Promise<RepositorySelectionResult> {
  if (signal?.aborted) return { kind: 'cancelled' }
  const repositories = await discoverRepositories(repositoryResolver)
  if (signal?.aborted) return { kind: 'cancelled' }

  if (repositories.length === 0) return { kind: 'unavailable' }
  const onlyRepository = repositories[0]
  if (repositories.length === 1 && onlyRepository) {
    return { kind: 'selected', repositoryPath: onlyRepository }
  }

  const cancellation = new CancellationTokenSource()
  const cancelPicker = (): void => cancellation.cancel()
  signal?.addEventListener('abort', cancelPicker, { once: true })
  try {
    if (signal?.aborted) cancellation.cancel()
    const selected = await window.showQuickPick(
      repositories.map(repositoryPath => ({
        label: path.basename(repositoryPath),
        description: repositoryPath,
        repositoryPath,
      })),
      { ignoreFocusOut: true, placeHolder: 'Select a Git repository' },
      cancellation.token,
    )
    if (!selected || signal?.aborted) return { kind: 'cancelled' }
    return { kind: 'selected', repositoryPath: selected.repositoryPath }
  } finally {
    signal?.removeEventListener('abort', cancelPicker)
    cancellation.dispose()
  }
}

export function discoverRepositories(
  repositoryResolver: IRepositoryResolver,
): Promise<ReadonlyArray<string>> {
  const candidates = collectRepositoryCandidates()
  return resolveRepositoryCandidates(candidates, repositoryResolver)
}

function collectRepositoryCandidates(): ReadonlyArray<string> {
  const candidates: string[] = []
  const activeUri = window.activeTextEditor?.document.uri
  if (activeUri?.scheme === 'file') candidates.push(path.dirname(activeUri.fsPath))
  for (const folder of workspace.workspaceFolders ?? []) candidates.push(folder.uri.fsPath)
  return candidates
}
