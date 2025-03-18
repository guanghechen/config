import type { IParseInlineHookCreator } from '@yozora/core-tokenizer';
import { type INode, type IThis, type IToken, type T } from './types';

export const parse: IParseInlineHookCreator<T, IToken, INode, IThis> =
  function (api) {
    return {
      parse: (tokens) =>
        tokens.map((token) => {
          const { code } = token;
          const node: INode = api.shouldReservePosition
            ? { type: token.nodeType, position: api.calcPosition(token), code }
            : { type: token.nodeType, code };
          return node;
        }),
    };
  };
