import React from 'react'
import { textTransformController } from '@/shared/api'
import type { ITransformerListItem } from '@/shared/types/api'

export interface ITransformerListResult {
  loading: boolean
  transformers: ITransformerListItem[]
  error?: string
  refresh: () => Promise<void>
}

export const useGetTransformerList = (): ITransformerListResult => {
  const [loading, setLoading] = React.useState(false)
  const [transformers, setTransformers] = React.useState<ITransformerListItem[]>([])
  const [error, setError] = React.useState<string | undefined>()

  const refresh = React.useCallback(async (): Promise<void> => {
    setLoading(true)
    setError(undefined)

    try {
      const list = await textTransformController.list()
      setTransformers(list)
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to fetch transformer list'
      setError(errorMessage)
      setTransformers([])
    } finally {
      setLoading(false)
    }
  }, [])

  return { loading, transformers, error, refresh }
}
