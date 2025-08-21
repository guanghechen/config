import type { ITextTransformConfig } from '../types/transform'

export const validateTransformConfig = (data: any): data is ITextTransformConfig => {
  return (
    data &&
    typeof data === 'object' &&
    typeof data.name === 'string' &&
    typeof data.split === 'string' &&
    typeof data.uuid === 'string' &&
    typeof data.parents === 'string' &&
    typeof data.title === 'string' &&
    Array.isArray(data.steps)
  )
}
