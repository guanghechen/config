import React from 'react'
import { useAutoCleanBlobUrl } from '@/common/hook/useAutoCleanBlobUrl'
import { getFile } from '@/hook/api/file'
import type { IFetchFileData, IFetchFileResult } from '@/shared/types/api'

export const useFileResult = <T extends IFetchFileData = IFetchFileData>(
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
    if (!filepath) {
      setState({ loading: false })
      return
    }

    let cancelled = false

    setState(v => ({ ...v, loading: true }))

    const handle = async (): Promise<void> => {
      setState(prevState => ({
        ...prevState,
        loading: true,
      }))
      const { data, text, url, error } = await getFile<T>(filepath)
      if (cancelled) {
        if (url) URL.revokeObjectURL(url)
        return
      }
      setState({ loading: false, data, text, url, error })
    }
    void handle()
    return () => {
      cancelled = true
    }
  }, [filepath, tick])

  useAutoCleanBlobUrl(state.url ?? null)
  return state
}
