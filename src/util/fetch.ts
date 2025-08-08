import type { Root } from '@yozora/ast'
import type { IHeadingToc } from '@yozora/ast-util'

export interface IMarkdownFileData {
  readonly ast: Root
  readonly toc: IHeadingToc
  readonly frontmatter: Record<string, unknown>
}

export interface IJsonFileData {
  readonly content: string
}

export interface IEventStreamFileData {
  readonly content: string
}

export interface IJsonlFileData {
  readonly content: string
}

export interface IPdfFileData {
  readonly url: string
}

export type IFetchFileData =
  | IMarkdownFileData
  | IJsonFileData
  | IEventStreamFileData
  | IJsonlFileData
  | IPdfFileData

export interface IFetchFileResult<T extends IFetchFileData = IFetchFileData> {
  readonly loading?: boolean
  readonly data?: T | undefined
  readonly text?: string | undefined
  readonly url?: string | undefined
  readonly error?: string | undefined
}

export async function fetchFile<T extends IFetchFileData = IFetchFileData>(
  workspace: string | null,
  filepath: string,
): Promise<IFetchFileResult<T>> {
  if (!filepath) return {}

  try {
    const query: Record<string, string> = { filepath }
    const params = new URLSearchParams(query) // Add your query parameters here
    if (workspace) params.set('workspace', workspace)

    const response = await fetch(`/api/file?${params}`)
    const contentType = response.headers.get('content-type')

    if (contentType?.includes('application/json')) {
      const data = await response.json()
      return { error: data.error, data: data.data }
    }

    if (contentType?.includes('text')) {
      const text = await response.text()
      return { text }
    } else if (contentType?.includes('image') || contentType?.includes('video')) {
      const blob = await response.blob()
      const objectUrl = URL.createObjectURL(blob)
      return { url: objectUrl }
    }
    return { error: `Unknown content type: ${contentType}` }
  } catch (error) {
    console.error('Failed to fetching file:', { workspace, filepath, error })
    return { error: 'Failed to fetching file: ' + JSON.stringify({ workspace, filepath, error }) }
  }
}
