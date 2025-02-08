import React from 'react'

export interface IFileResult {
  readonly loading: boolean
  readonly text: string | undefined
  readonly url: string | undefined
  readonly error: string | undefined
}

export const useFileResult = (filepath: string, tick: number): IFileResult => {
  const [state, setState] = React.useState<IFileResult>({
    loading: true,
    text: undefined,
    url: undefined,
    error: undefined,
  })

  React.useEffect(() => {
    const fetchFile = async (): Promise<void> => {
      setState({
        loading: true,
        text: undefined,
        url: undefined,
        error: undefined,
      })

      if (!filepath) return

      try {
        const response = await fetch(`/api/file/${encodeURIComponent(filepath)}`)
        const contentType = response.headers.get('content-type')

        if (contentType?.includes('text') || contentType?.includes('json')) {
          const textContent = await response.text()
          setState({ loading: false, text: textContent, url: undefined, error: undefined })
        } else if (contentType?.includes('image') || contentType?.includes('video')) {
          const blob = await response.blob()
          const objectUrl = URL.createObjectURL(blob)
          setState({ loading: false, text: undefined, url: objectUrl, error: undefined })
        }
      } catch (error) {
        console.error('Failed to fetching file:', { filepath, error })
        setState({
          loading: false,
          text: undefined,
          url: undefined,
          error: 'Failed to fetching file: ' + JSON.stringify({ filepath, error }),
        })
      }
    }
    void fetchFile()
  }, [filepath, tick])

  React.useEffect(() => {
    return () => {
      if (state.url) {
        URL.revokeObjectURL(state.url)
      }
    }
  }, [state.url])
  return state
}
