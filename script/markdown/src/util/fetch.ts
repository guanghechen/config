export interface IFetchFileResult {
  readonly loading?: boolean
  readonly text: string | undefined
  readonly url: string | undefined
  readonly error: string | undefined
}

export async function fetchFile(
  filepath: string,
  base: string | undefined,
): Promise<IFetchFileResult> {
  if (!filepath) return { text: undefined, url: undefined, error: undefined }

  try {
    const query: Record<string, string> = { filepath }
    if (base) query.base = base

    const params = new URLSearchParams(query) // Add your query parameters here
    const response = await fetch(`/api/file?${params}`)
    const contentType = response.headers.get('content-type')

    if (contentType?.includes('text') || contentType?.includes('json')) {
      const text = await response.text()
      return { text: text, url: undefined, error: undefined }
    } else if (contentType?.includes('image') || contentType?.includes('video')) {
      const blob = await response.blob()
      const objectUrl = URL.createObjectURL(blob)
      return { text: undefined, url: objectUrl, error: undefined }
    }
    return { text: undefined, url: undefined, error: `Unknown content type: ${contentType}` }
  } catch (error) {
    console.error('Failed to fetching file:', { filepath, error })
    return {
      text: undefined,
      url: undefined,
      error: 'Failed to fetching file: ' + JSON.stringify({ filepath, error }),
    }
  }
}
