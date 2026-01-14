import type { IPlatform } from '../env'

export interface IMatch {
  readonly matched_text: string
  readonly matched_groups: string[]
  readonly offset_start: number
  readonly offset_end: number
}

export interface IPatch {
  name: string
  version: string
  platform: IPlatform[]
  search: string | RegExp
  replace: (original: string, matches: IMatch[]) => string
  verify: (text: string) => boolean
}

export interface IApplyOptions {
  patches: IPatch[]
  stopOnFirst?: boolean
}
