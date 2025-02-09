import React from 'react'
import type { IFetchFileResult } from '@/util/fetch'
import { fetchFile } from '@/util/fetch'

export const useFileResult = (filepath: string, tick: number): IFetchFileResult => {
  const [state, setState] = React.useState<IFetchFileResult>({
    loading: true,
    data: undefined,
    text: undefined,
    url: undefined,
    error: undefined,
  })

  React.useEffect(() => {
    const handle = async (): Promise<void> => {
      setState({
        loading: true,
        data: undefined,
        text: undefined,
        url: undefined,
        error: undefined,
      })
      const { data, text, url, error } = await fetchFile(filepath)
      setState({ loading: false, data, text, url, error })
    }
    void handle()
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
