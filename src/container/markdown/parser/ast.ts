import type { Node } from '@yozora/ast'

export const InlineCitationType = 'inlineCitation'
// eslint-disable-next-line @typescript-eslint/no-redeclare
export type InlineCitationType = typeof InlineCitationType
export interface InlineCitation extends Node<InlineCitationType> {
  readonly code: string
}
