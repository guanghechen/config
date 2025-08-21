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
    // Step 1: Split the text using function string
    let texts: string[]
    const splitConfig = config.split.trim()
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
        } else if (step.type === TextTransformStepTypeEnum.MAP) {
          iterators = iterators.map(func)
        } else {
          return {
            nodes: [],
            error: `Invalid step type: ${step.type}`,
          }
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
      const uuidFunc = new Function(
        'item',
        'index',
        'items',
        `return (${config.uuid})(item, index, items)`,
      )
      const parentUuidFunc = new Function(
        'item',
        'index',
        'items',
        `return (${config.parents})(item, index, items)`,
      )
      const titleFunc = new Function('element', 'index', `return (${config.title})(element, index)`)
      const descFunc = new Function('element', 'index', `return (${config.desc})(element, index)`)

      const nodes: ITextTransformedNode[] = results.map((item: any, index: number) => {
        const parentUuidResult = parentUuidFunc(item, index, results)

        // Ensure parent_uuid is always an array
        const parents: string[] = Array.isArray(parentUuidResult)
          ? parentUuidResult.filter(uuid => !!uuid && typeof uuid === 'string')
          : !!parentUuidResult && typeof parentUuidResult === 'string'
            ? [parentUuidResult]
            : []

        return {
          uuid: uuidFunc(item, index, results),
          parents: parents,
          title: titleFunc(item, index),
          desc: descFunc(item, index),
          data: item,
          index: index,
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
