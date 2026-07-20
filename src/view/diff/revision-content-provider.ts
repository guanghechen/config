import { Uri, workspace, type CancellationToken, type TextDocumentContentProvider } from 'vscode'
import { GitBlobDisplayError } from '../../git/git-client'

export const REVISION_SCHEME = 'vsgit'

interface IRevisionResource {
  readonly repositoryPath: string
  readonly commit: string
  readonly filePath: string
  readonly empty: boolean
}

export interface IRevisionContentSource {
  readTextFile(
    repositoryPath: string,
    commit: string,
    filePath: string,
    maxBytes: number,
    signal: AbortSignal,
  ): Promise<string>
}

export class RevisionContentProvider implements TextDocumentContentProvider {
  public constructor(private readonly contentSource: IRevisionContentSource) {}

  public createUri(
    repositoryPath: string,
    commit: string,
    filePath: string,
    side: 'base' | 'target',
    empty = false,
  ): Uri {
    const query = new URLSearchParams({
      repositoryPath,
      commit,
      filePath,
      empty: empty ? '1' : '0',
    })
    return Uri.from({
      scheme: REVISION_SCHEME,
      authority: side,
      path: `/${filePath}`,
      query: query.toString(),
    })
  }

  public async provideTextDocumentContent(uri: Uri, token: CancellationToken): Promise<string> {
    const resource = parseRevisionResource(uri)
    if (resource.empty) return ''

    const controller = new AbortController()
    const cancellation = token.onCancellationRequested(() => controller.abort())
    try {
      const maxBytes = workspace.getConfiguration('vsgit').get('maxBlobBytes', 5 * 1024 * 1024)
      return await this.contentSource.readTextFile(
        resource.repositoryPath,
        resource.commit,
        resource.filePath,
        maxBytes,
        controller.signal,
      )
    } catch (cause) {
      if (cause instanceof GitBlobDisplayError) {
        return `VSGit cannot display this revision.\n\n${cause.message}\n`
      }
      throw cause
    } finally {
      cancellation.dispose()
    }
  }
}

function parseRevisionResource(uri: Uri): IRevisionResource {
  const query = new URLSearchParams(uri.query)
  const repositoryPath = query.get('repositoryPath')
  const commit = query.get('commit')
  const filePath = query.get('filePath')
  if (!repositoryPath || !commit || !filePath) throw new Error('VSGit revision URI is invalid.')
  return {
    repositoryPath,
    commit,
    filePath,
    empty: query.get('empty') === '1',
  }
}
