import React from 'react'
import { textTransformController } from '@/shared/api'
import type { ITextTransformConfig } from '@/shared/types'

export interface ITransformerSaveResult {
  loading: boolean
  error?: string
  save: (name: string, config: ITextTransformConfig) => Promise<void>
}

export async function postTransformer(name: string, config: ITextTransformConfig): Promise<void> {
  await textTransformController.save(name, config)
}

export const usePostTransformer = (): ITransformerSaveResult => {
  const [loading, setLoading] = React.useState(false)
  const [error, setError] = React.useState<string | undefined>()

  const save = React.useCallback(
    async (name: string, config: ITextTransformConfig): Promise<void> => {
      if (!name.trim()) {
        throw new Error('Please enter a name for the transformer')
      }

      setLoading(true)
      setError(undefined)

      try {
        await postTransformer(name, config)
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Failed to save transformer'
        setError(errorMessage)
        throw err
      } finally {
        setLoading(false)
      }
    },
    [],
  )

  return { loading, error, save }
}
