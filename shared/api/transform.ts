import { ApiRoutePathEnum } from '../constant/api'
import type { ITransformerListItem, ITransformerSaveRequestPayload } from '../types/api/transform'
import type { ITextTransformConfig } from '../types/transform'
import { requester } from './requester'

export class TextTransformController {
  public async list(): Promise<ITransformerListItem[]> {
    const response = await requester.get(ApiRoutePathEnum.TEXT_TRANSFORM_LIST)
    const result = await response.json()

    if (response.ok && result.data?.transformers) {
      return result.data.transformers
    } else {
      throw new Error(result.error || 'Failed to load transformers')
    }
  }

  public async resolve(name: string): Promise<ITextTransformConfig> {
    const response = await requester.get(
      `${ApiRoutePathEnum.TEXT_TRANSFORM}/${encodeURIComponent(name)}`,
    )
    const result = await response.json()

    if (!response.ok || !result.data?.transformer) {
      throw new Error(result.error || 'Failed to load transformer')
    }

    const transformer = result.data.transformer

    return {
      name: transformer.name,
      desc: transformer.desc || "(element, index) => ''",
      split: transformer.split || '\n',
      uuid: transformer.uuid || '',
      parents: transformer.parents || '() => []',
      parents_virtual: transformer.parents_virtual || '() => []',
      title: transformer.title || "(element, index) => ''",
      chainPaths: transformer.chainPaths || [],
      steps: (transformer.steps || []).map((step: any, index: number) => ({
        id: `loaded-${Date.now()}-${index}`,
        type: step.type || 'map',
        code: step.code || '',
        skip: step.skip ?? false,
      })),
    }
  }

  public async save(name: string, config: ITextTransformConfig): Promise<void> {
    const saveData: ITransformerSaveRequestPayload = {
      name: name.trim(),
      desc: config.desc,
      split: config.split,
      uuid: config.uuid,
      parents: config.parents,
      parents_virtual: config.parents_virtual,
      title: config.title,
      chainPaths: config.chainPaths,
      steps: config.steps.map(step => ({
        type: step.type,
        code: step.code,
        skip: step.skip ?? false,
      })),
    }

    const response = await requester.post(
      `${ApiRoutePathEnum.TEXT_TRANSFORM}/${encodeURIComponent(name.trim())}`,
      saveData,
    )

    const result = await response.json()

    if (!response.ok) {
      throw new Error(result.error || 'Failed to save transformer')
    }
  }
}

export const textTransformController = new TextTransformController()
