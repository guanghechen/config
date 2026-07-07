import type { Node } from '@yozora/ast'

export const InlineCitationType = 'inlineCitation'

export type InlineCitationType = typeof InlineCitationType
export interface InlineCitation extends Node<InlineCitationType> {
  readonly code: string
}
