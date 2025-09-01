import React from 'react'
import { fileController } from '@/shared/api'
import type { IFetchFileData, IFetchFileResult } from '@/shared/types/api'

export async function getFile<T extends IFetchFileData = IFetchFileData>(
  workspace: string | null,
  filepath: string,
): Promise<IFetchFileResult<T>> {
  try {
    return await fileController.resolve<T>(workspace, filepath)
  } catch (error) {
    // Handle authentication errors gracefully
    if (error instanceof Error && error.message === 'Authentication required') {
      return { error: 'Authentication required' }
    } else {
      return { error: `Failed to fetch file: ${error}` }
    }
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
        const fetchResult = await fileController.resolve<T>(workspace, filepath)
        if (!cancelled) {
          setResult(fetchResult)
        }
      } catch (error) {
        if (!cancelled) {
          // Handle authentication errors gracefully
          if (error instanceof Error && error.message === 'Authentication required') {
            setResult({ error: 'Authentication required' })
          } else {
            setResult({ error: `Failed to fetch file: ${error}` })
          }
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
