import type { ICommitHistorySnapshot } from '../../history/model'

export type CommitSearchViewOperationResult =
  | { readonly kind: 'applied'; readonly snapshot: ICommitHistorySnapshot | null }
  | { readonly kind: 'cancelled' }
  | { readonly kind: 'unavailable' }
