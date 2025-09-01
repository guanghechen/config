import type { TextTransformStepTypeEnum } from '../transform'

export type ITransformerListRequestParams = Record<string, never>

export type ITransformerListRequestPayload = Record<string, never>

export interface ITransformerListItem {
  readonly name: string
  readonly lastModified?: string
}

export interface ITransformerListResponseResult {
  readonly transformers: ITransformerListItem[]
}

export interface ITransformerResolveRequestParams {
  readonly name: string // Used in URL path parameter
}

export type ITransformerResolveRequestPayload = Record<string, never>

export interface ITransformerResolveResponseResult {
  readonly transformer: {
    readonly name: string
    readonly desc: string
    readonly split: string
    readonly steps: Array<{
      readonly type: TextTransformStepTypeEnum
      readonly code: string
      readonly skip: boolean
    }>
    readonly uuid: string
    readonly parents: string
    readonly parents_virtual: string
    readonly title: string
    readonly chainPaths?: string[]
  }
}

export interface ITransformerSaveRequestParams {
  readonly name: string // Used in URL path parameter
}

export interface ITransformerSaveRequestPayload {
  readonly name: string
  readonly desc: string
  readonly split: string
  readonly steps: Array<{
    readonly type: TextTransformStepTypeEnum
    readonly code: string
    readonly skip: boolean
  }>
  readonly uuid: string
  readonly parents: string
  readonly parents_virtual: string
  readonly title: string
  readonly chainPaths?: string[]
}

export type ITransformerSaveResponseResult = Record<string, never>
