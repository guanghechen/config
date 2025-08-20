/* eslint-disable no-new-func */
import type { ITextTransformConfig, ITextTransformedNode } from '@/shared/types'
import { TextTransformStepTypeEnum } from '@/shared/types'

interface ITransformResult {
  readonly nodes: ITextTransformedNode[]
  readonly error?: string
}

export const transformTextToNodes = (
  text: string,
  config: ITextTransformConfig,
): ITransformResult => {
  try {
    // Step 1: Split the text
    let texts: string[]
    const splitConfig = config.split.trim()
    if (splitConfig.startsWith('/') && splitConfig.endsWith('/')) {
      try {
        const regexPattern = splitConfig.slice(1, -1)
        const regex = new RegExp(regexPattern)
        texts = text.split(regex)
      } catch (error) {
        return {
          nodes: [],
          error: `Invalid regex pattern: ${error instanceof Error ? error.message : 'Unknown error'}`,
        }
      }
    } else {
      try {
        const splitFunction = new Function('text', `return (${splitConfig})(text)`)
        texts = splitFunction(text)

        if (!Array.isArray(texts)) {
          return {
            nodes: [],
            error: 'Split function must return an array of strings',
          }
        }
      } catch (error) {
        return {
          nodes: [],
          error: `Invalid split function: ${error instanceof Error ? error.message : 'Unknown error'}`,
        }
      }
    }

    // Step 2: Apply transform steps
    let iterators: ArrayIterator<unknown> = texts.values()
    for (const step of config.steps) {
      if (step.skip) continue

      try {
        const func: (ele: unknown, index: number) => boolean = new Function(
          'element',
          'index',
          `return (${step.code})(element, index)`,
        ) as any

        if (step.type === TextTransformStepTypeEnum.FILTER) {
          iterators = iterators.filter(func)
        } else {
          iterators = iterators.map(func)
        }
      } catch (error) {
        return {
          nodes: [],
          error: `Invalid ${step.type} step: ${error instanceof Error ? error.message : 'Unknown error'}`,
        }
      }
    }
    const results: unknown[] = Array.from(iterators)

    // Step 3: Apply identifier functions
    try {
      const uuidFunc = new Function('item', 'index', `return (${config.uuid})(item, index)`)
      const parentUuidFunc = new Function(
        'item',
        'index',
        `return (${config.parents})(item, index)`,
      )

      const nodes: ITextTransformedNode[] = results.map((item: any, index: number) => {
        const parentUuidResult = parentUuidFunc(item, index)

        // Ensure parent_uuid is always an array
        let parents: string[]
        if (parentUuidResult === null || parentUuidResult === undefined) {
          parents = []
        } else if (Array.isArray(parentUuidResult)) {
          parents = parentUuidResult.filter(uuid => uuid !== null && uuid !== undefined)
        } else {
          parents = [parentUuidResult].filter(uuid => uuid !== null && uuid !== undefined)
        }

        return {
          uuid: uuidFunc(item, index),
          parents: parents,
          data: item,
        }
      })

      return { nodes }
    } catch (error) {
      return {
        nodes: [],
        error: `Invalid identifier function: ${error instanceof Error ? error.message : 'Unknown error'}`,
      }
    }
  } catch (error) {
    return {
      nodes: [],
      error: `Transform failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
    }
  }
}
