import React from 'react'
import type { IFetchFileResult } from '@/util/fetch'
import { fetchFile } from '@/util/fetch'

export const useFileResult = (
  workspace: string | null,
  filepath: string | null,
  tick: number,
): IFetchFileResult => {
  const [state, setState] = React.useState<IFetchFileResult>({
    loading: false,
    data: undefined,
    text: undefined,
    url: undefined,
    error: undefined,
  })

  React.useEffect(() => {
    if (!filepath) return

    setState(v => ({ ...v, loading: true }))

    const handle = async (): Promise<void> => {
      setState(prevState => ({
        ...prevState,
        loading: true,
      }))
      const { data, text, url, error } = await fetchFile(workspace, filepath)
      setState({ loading: false, data, text, url, error })
    }
    void handle()
  }, [workspace, filepath, tick])

  React.useEffect(() => {
    return () => {
      if (state.url) {
        URL.revokeObjectURL(state.url)
      }
    }
  }, [state.url])
  return state
}
