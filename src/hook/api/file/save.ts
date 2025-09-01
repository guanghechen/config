import React from 'react'
import { fileController } from '@/shared/api'
import type { IFileSaveRequestPayload } from '@/shared/types/api'

export interface IFileSaveResult {
  loading: boolean
  error?: string
  save: (params: IFileSaveRequestPayload) => Promise<void>
}

export async function postFile(params: IFileSaveRequestPayload): Promise<void> {
  await fileController.save(params)
}

export const usePostFile = (): IFileSaveResult => {
  const [loading, setLoading] = React.useState(false)
  const [error, setError] = React.useState<string | undefined>()

  const save = React.useCallback(async (params: IFileSaveRequestPayload): Promise<void> => {
    setLoading(true)
    setError(undefined)

    try {
      await postFile(params)
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred'
      setError(errorMessage)
      throw err
    } finally {
      setLoading(false)
    }
  }, [])

  return { loading, error, save }
}
