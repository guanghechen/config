import React from 'react'
import { getFile } from '@/hook/api/file'
import type { IFetchFileData, IFetchFileResult } from '@/shared/types/api'

export const useFileResult = <T extends IFetchFileData = IFetchFileData>(
  workspace: string | null,
  filepath: string | null,
  tick: number,
): IFetchFileResult<T> => {
  const [state, setState] = React.useState<IFetchFileResult<T>>({
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
      const { data, text, url, error } = await getFile<T>(workspace, filepath)
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
