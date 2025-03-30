import type {
  IInlineTokenizer,
  IMatchInlineHookCreator,
  IParseInlineHookCreator,
} from '@yozora/core-tokenizer'
import { BaseInlineTokenizer, TokenizerPriority } from '@yozora/core-tokenizer'
import { match } from './match'
import { parse } from './parse'
import type {
  IDelimiter,
  INode,
  IThis,
  IToken,
  ITokenizerProps as ITokenizerProperties,
  T,
} from './types'
import { uniqueName } from './types'

/**
 * Lexical Analyzer for inlineCitation.
 */
export class InlineCitationTokenizer
  extends BaseInlineTokenizer<T, IDelimiter, IToken, INode>
  implements IInlineTokenizer<T, IDelimiter, IToken, INode>
{
  /* istanbul ignore next */
  constructor(properties: ITokenizerProperties = {}) {
    super({
      name: properties.name ?? uniqueName,
      priority: properties.priority ?? TokenizerPriority.ATOMIC,
    })
  }

  public override readonly match: IMatchInlineHookCreator<T, IDelimiter, IToken> = match

  public override readonly parse: IParseInlineHookCreator<T, IToken, INode> = parse
}
