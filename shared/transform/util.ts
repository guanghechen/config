import type { ITextTransformConfig } from '@/shared/transform/types'

export const validateTransformerData = (data: any): data is ITextTransformConfig => {
  return (
    data &&
    typeof data === 'object' &&
    typeof data.name === 'string' &&
    typeof data.split === 'string' &&
    typeof data.uuid === 'string' &&
    typeof data.parents === 'string' &&
    Array.isArray(data.steps)
  )
}
