export enum TextTransformStepTypeEnum {
  FILTER = 'filter',
  MAP = 'map',
}

export interface ITextTransformStep {
  readonly id: string
  readonly type: TextTransformStepTypeEnum
  readonly code: string
  readonly skip: boolean
}

export interface ITextTransformStepData {
  readonly type: TextTransformStepTypeEnum
  readonly code: string
  readonly skip: boolean
}

export interface ITextTransformExportData {
  readonly name: string
  readonly desc: string
  readonly uuid: string
  readonly parents: string
  readonly title: string
  readonly split: string
  readonly steps: ITextTransformStepData[]
  readonly chainPaths?: string[]
}

export interface ITextTransformConfig {
  readonly name: string
  readonly desc: string
  readonly split: string
  readonly steps: ITextTransformStep[]
  readonly uuid: string
  readonly parents: string
  readonly title: string
  readonly chainPaths?: string[]
}

export interface ITextTransformedNode {
  readonly uuid: string
  readonly parents: string[]
  readonly title: string
  readonly desc: string
  readonly data: unknown
}
