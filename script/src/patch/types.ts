import type { IPlatform } from "../env"

export interface IPatch {
  name: string
  version?: string
  platform: IPlatform[]
  search: string | RegExp
  replace: string
}

export interface IApplyOptions {
  patches: IPatch[]
  stopOnFirst?: boolean
}
