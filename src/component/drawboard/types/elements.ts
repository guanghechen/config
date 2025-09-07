// Base element properties
export interface IDrawboardElementBase {
  id: string
  type: IElementType
  x: number
  y: number
  width: number
  height: number
  angle: number
  strokeColor: string
  backgroundColor: string
  fillStyle: IFillStyle
  strokeWidth: number
  strokeStyle: IStrokeStyle
  roughness: number
  opacity: number
  strokeSharpness?: IStrokeSharpness
  seed: number
  versionNonce: number
  isDeleted: boolean
  boundElements?: IBoundElement[] | null
  updated: number
}

export type IElementType = 'line' | 'rectangle' | 'circle' | 'arrow'
export type IFillStyle = 'solid' | 'hachure' | 'cross-hatch'
export type IStrokeStyle = 'solid' | 'dashed' | 'dotted'
export type IStrokeSharpness = 'sharp' | 'round'

export interface IBoundElement {
  id: string
  type: 'arrow'
}

export interface IDrawboardLineElement extends IDrawboardElementBase {
  type: 'line'
  points: Array<[number, number]>
  lastCommittedPoint?: [number, number]
}

export interface IDrawboardRectangleElement extends IDrawboardElementBase {
  type: 'rectangle'
}

export interface IDrawboardCircleElement extends IDrawboardElementBase {
  type: 'circle'
}

// Arrow elements share line properties but have their own type
export interface IDrawboardArrowElement extends Omit<IDrawboardElementBase, 'type'> {
  type: 'arrow'
  points: Array<[number, number]>
  lastCommittedPoint?: [number, number]
  startArrowhead?: 'arrow' | 'dot' | 'bar'
  endArrowhead?: 'arrow' | 'dot' | 'bar'
}

export type IDrawboardElement =
  | IDrawboardLineElement
  | IDrawboardRectangleElement
  | IDrawboardCircleElement
  | IDrawboardArrowElement
