import React from 'react'
import { textTransformController } from '@/shared/api'
import type { ITextTransformConfig } from '@/shared/types'

export interface ITransformerLoadResult {
  loading: boolean
  error?: string
  load: (name: string) => Promise<ITextTransformConfig>
}

export const useGetTransformer = (): ITransformerLoadResult => {
  const [loading, setLoading] = React.useState(false)
  const [error, setError] = React.useState<string | undefined>()

  const load = React.useCallback(async (name: string): Promise<ITextTransformConfig> => {
    setLoading(true)
    setError(undefined)

    try {
      const config = await textTransformController.resolve(name)
      return config
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Failed to load transformer'
      setError(errorMessage)
      throw err
    } finally {
      setLoading(false)
    }
  }, [])

  return { loading, error, load }
}
