/* eslint-disable no-new-func */
import type { INode, ITransformConfig } from '@/shared/transformer'

export interface ITransformResult {
  readonly nodes: INode[]
  readonly error?: string
}

export const transformTextToNodes = (text: string, config: ITransformConfig): ITransformResult => {
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

    // Step 2: Apply transformer functions
    let processedResult: any = texts
    for (const transformer of config.transformers) {
      if (transformer.skipped) continue

      try {
        const func = new Function(
          'element',
          'index',
          'elements',
          `return (${transformer.function})(element, index, elements)`,
        )

        if (transformer.type === 'filter') {
          processedResult = processedResult.filter(func)
        } else {
          processedResult = processedResult.map(func)
        }
      } catch (error) {
        return {
          nodes: [],
          error: `Invalid ${transformer.type} transformer: ${error instanceof Error ? error.message : 'Unknown error'}`,
        }
      }
    }

    // Step 3: Apply identifier functions
    try {
      const uuidFunc = new Function('item', 'index', `return (${config.uuidFunction})(item, index)`)
      const parentUuidFunc = new Function(
        'item',
        'index',
        `return (${config.parentUuidFunction})(item, index)`,
      )

      const nodes: INode[] = processedResult.map((item: any, index: number) => ({
        uuid: uuidFunc(item, index),
        parent_uuid: parentUuidFunc(item, index),
        data: item,
      }))

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
