export interface ITransformerFunction {
  readonly id: string
  readonly type: 'filter' | 'map'
  readonly function: string
  readonly skipped?: boolean
}

export interface ITransformerFunctionData {
  readonly type: 'filter' | 'map'
  readonly code: string
  readonly skip: boolean
}

export interface ITransformExportData {
  readonly uuid: string
  readonly parent_uuid: string
  readonly split: string
  readonly transformers: ITransformerFunctionData[]
}

export interface ITransformConfig {
  readonly name: string
  readonly split: string
  readonly transformers: ITransformerFunction[]
  readonly uuidFunction: string
  readonly parentUuidFunction: string
}

export interface INode {
  readonly uuid: string
  readonly parent_uuid: string[]
  readonly data: any
}
