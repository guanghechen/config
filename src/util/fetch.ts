// @deprecated This file is deprecated. Use the hooks from @/hook/api instead.
// Types and functions in this file have been moved to @/hook/api/file.ts
// This file is kept temporarily for backward compatibility.

import type {
  IEventStreamFileData,
  IFetchFileData,
  IFetchFileResult,
  IHtmlFileData,
  IJsonFileData,
  IJsonlFileData,
  IMarkdownFileData,
  IPdfFileData,
  ISvgFileData,
  ITextFileData,
} from '@/shared/types/api'

// Re-export types for backward compatibility
export type {
  IMarkdownFileData,
  IJsonFileData,
  IEventStreamFileData,
  IJsonlFileData,
  IPdfFileData,
  ISvgFileData,
  IHtmlFileData,
  ITextFileData,
  IFetchFileData,
  IFetchFileResult,
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

    if (contentType?.includes('image/svg+xml')) {
      const content: string = await response.text()
      const data: ISvgFileData = { content }
      return { data: data as T }
    }

    if (contentType?.includes('text/html')) {
      const content: string = await response.text()
      const data: IHtmlFileData = { content }
      return { data: data as T }
    }

    if (contentType?.includes('text/plain')) {
      const content: string = await response.text()
      const data: ITextFileData = { content }
      return { data: data as T }
    }

    if (contentType?.includes('text')) {
      const text = await response.text()
      return { text }
    }

    if (contentType?.includes('image') || contentType?.includes('video')) {
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
