/* eslint-disable @typescript-eslint/prefer-literal-enum-member */
const bit: number = 1

export enum ModeEnum {
  VIEW = bit << 0,
  RAW = bit << 1,
  TRANSFORM = bit << 2,
}

export interface IFilterMapFunction {
  readonly id: string
  readonly type: 'filter' | 'map'
  readonly function: string
  readonly skipped?: boolean
}

export interface IFilterMapFunctionData {
  readonly type: 'filter' | 'map'
  readonly code: string
  readonly skip: boolean
}

export interface ITransformExportData {
  readonly uuid: string
  readonly parent_uuid: string
  readonly split: string
  readonly fms: IFilterMapFunctionData[]
}

export interface ITransformConfig {
  readonly split: string
  readonly filterMap: IFilterMapFunction[]
  readonly uuidFunction: string
  readonly parentUuidFunction: string
}

export interface INode {
  readonly uuid: string
  readonly parent_uuid: string | null
  readonly data: any
}

export interface ITextViewData {
  readonly mode: ModeEnum
  readonly transformConfig?: ITransformConfig
}
