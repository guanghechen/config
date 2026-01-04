import type {
  IBaseInlineTokenizerProps,
  IPartialInlineToken,
  ITokenDelimiter,
  ITokenizer,
} from '@yozora/core-tokenizer'
import type { InlineCitation, InlineCitationType } from '../ast'

export const uniqueName = '@/tokenizer-inline-citation'

export type T = InlineCitationType
export type INode = InlineCitation

export interface IToken extends IPartialInlineToken<T> {
  code: string
}

export interface IDelimiter extends ITokenDelimiter {
  type: 'full'
  code: string
}

export type IThis = ITokenizer

export type ITokenizerProps = Partial<IBaseInlineTokenizerProps>
