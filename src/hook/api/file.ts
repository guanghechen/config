import type { Root } from '@yozora/ast'
import type { IHeadingToc } from '@yozora/ast-util'
import React from 'react'

export interface IMarkdownFileData {
  readonly ast: Root
  readonly toc: IHeadingToc
  readonly frontmatter: Record<string, unknown>
}

export interface IJsonFileData {
  readonly content: string
}

export interface IJsonlFileData {
  readonly content: string
}

export interface IPdfFileData {
  readonly url: string
}

export interface ISvgFileData {
  readonly content: string
}

export interface IHtmlFileData {
  readonly content: string
}

export interface ITextFileData {
  readonly content: string
}

export type IFetchFileData =
  | IMarkdownFileData
  | IJsonFileData
  | IJsonlFileData
  | IPdfFileData
  | ISvgFileData
  | IHtmlFileData
  | ITextFileData

export interface IFetchFileResult<T extends IFetchFileData = IFetchFileData> {
  readonly loading?: boolean
  readonly data?: T | undefined
  readonly text?: string | undefined
  readonly url?: string | undefined
  readonly error?: string | undefined
}

export async function getFile<T extends IFetchFileData = IFetchFileData>(
  workspace: string | null,
  filepath: string,
): Promise<IFetchFileResult<T>> {
  if (!filepath) return {}

  try {
    const query: Record<string, string> = { filepath }
    const params = new URLSearchParams(query)
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

export const useGetFile = <T extends IFetchFileData = IFetchFileData>(
  workspace: string | null,
  filepath: string,
  tick: number,
): IFetchFileResult<T> => {
  const [result, setResult] = React.useState<IFetchFileResult<T>>({ loading: true })

  React.useEffect(() => {
    let cancelled = false

    async function handleFetch(): Promise<void> {
      if (!filepath) {
        setResult({})
        return
      }

      setResult({ loading: true })

      try {
        const fetchResult = await getFile<T>(workspace, filepath)
        if (!cancelled) {
          setResult(fetchResult)
        }
      } catch (error) {
        if (!cancelled) {
          setResult({ error: `Failed to fetch file: ${error}` })
        }
      }
    }

    void handleFetch()

    return (): void => {
      cancelled = true
    }
  }, [workspace, filepath, tick])

  return result
}
