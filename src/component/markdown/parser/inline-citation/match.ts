import type { INodePoint } from '@yozora/character'
import { AsciiCodePoint } from '@yozora/character'
import { genFindDelimiter } from '@yozora/core-tokenizer'
import type {
  IMatchInlineHookCreator,
  IResultOfProcessSingleDelimiter,
} from '@yozora/core-tokenizer'
import { InlineCitationType } from '../ast'
import type { IDelimiter, IToken, T } from './types'

export const match: IMatchInlineHookCreator<T, IDelimiter, IToken> = function (api) {
  return {
    findDelimiter: () => genFindDelimiter<IDelimiter>(_findDelimiter),
    processSingleDelimiter,
  }

  function _findDelimiter(startIndex: number, endIndex: number): IDelimiter | null {
    const nodePoints: ReadonlyArray<INodePoint> = api.getNodePoints()

    for (let index = startIndex; index < endIndex; ) {
      const c = nodePoints[index].codePoint
      switch (c) {
        case AsciiCodePoint.BACKSLASH: {
          index += 2
          break
        }
        case AsciiCodePoint.OPEN_BRACKET: {
          if (index + 6 >= endIndex) return null

          const s: number = index

          index += 1
          const c1 = nodePoints[index].codePoint
          const c2 = nodePoints[index + 1].codePoint
          const c3 = nodePoints[index + 2].codePoint

          if (
            c1 !== AsciiCodePoint.OPEN_BRACKET ||
            (c2 !== AsciiCodePoint.LOWERCASE_C && c2 !== AsciiCodePoint.UPPERCASE_C) ||
            c3 !== AsciiCodePoint.COLON
          ) {
            break
          }

          let code: string = ''
          for (index += 3; index < endIndex; ++index) {
            const cc = nodePoints[index].codePoint
            if (cc === AsciiCodePoint.CLOSE_BRACKET) break
            code += String.fromCodePoint(cc)
          }

          if (
            code.length === 0 ||
            index + 1 >= endIndex ||
            nodePoints[index].codePoint !== AsciiCodePoint.CLOSE_BRACKET ||
            nodePoints[index + 1].codePoint !== AsciiCodePoint.CLOSE_BRACKET
          ) {
            break
          }

          const delimiter: IDelimiter = {
            type: 'full',
            startIndex: s,
            endIndex: index + 2,
            code,
          }
          return delimiter
        }
        default: {
          index += 1
        }
      }
    }
    return null
  }
}

function processSingleDelimiter(delimiter: IDelimiter): IResultOfProcessSingleDelimiter<T, IToken> {
  const token: IToken = {
    nodeType: InlineCitationType,
    code: delimiter.code,
    startIndex: delimiter.startIndex,
    endIndex: delimiter.endIndex,
  }
  return [token]
}
