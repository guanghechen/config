import type { Root } from '@yozora/ast'
import type { IHeadingToc } from '@yozora/ast-util'

export interface IMarkdownData {
  readonly ast: Root
  readonly toc: IHeadingToc
  readonly frontmatter: Record<string, unknown>
}

export interface IFetchFileResult {
  readonly loading?: boolean
  readonly data?: IMarkdownData | undefined
  readonly text?: string | undefined
  readonly url?: string | undefined
  readonly error?: string | undefined
}

export async function fetchFile(
  workspace: string | null,
  filepath: string,
): Promise<IFetchFileResult> {
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
