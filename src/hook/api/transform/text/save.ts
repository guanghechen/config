import React from 'react'
import type { ITextTransformConfig, TextTransformStepTypeEnum } from '@/shared/transform/types'

export interface ITransformerSaveData {
  name: string
  split: string
  steps: Array<{
    type: TextTransformStepTypeEnum
    code: string
    skip: boolean
  }>
  uuid: string
  parents: string
}

export interface ITransformerSaveResult {
  loading: boolean
  error?: string
  save: (name: string, config: ITextTransformConfig) => Promise<void>
}

export async function postTransformer(name: string, config: ITextTransformConfig): Promise<void> {
  const saveData: ITransformerSaveData = {
    name: name.trim(),
    split: config.split,
    uuid: config.uuid,
    parents: config.parents,
    steps: config.steps.map(step => ({
      type: step.type,
      code: step.code,
      skip: step.skip ?? false,
    })),
  }

  const response = await fetch(`/api/transform/text/${encodeURIComponent(name.trim())}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(saveData),
  })

  const result = await response.json()

  if (!response.ok) {
    throw new Error(result.error || 'Failed to save transformer')
  }
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
