// Base element properties
export interface IDrawboardElementBase {
  id: string
  type: ElementType
  x: number
  y: number
  width: number
  height: number
  angle: number
  strokeColor: string
  backgroundColor: string
  fillStyle: FillStyle
  strokeWidth: number
  strokeStyle: StrokeStyle
  roughness: number
  opacity: number
  strokeSharpness?: StrokeSharpness
  seed: number
  versionNonce: number
  isDeleted: boolean
  boundElements?: IBoundElement[] | null
  updated: number
}

export type ElementType = 'line' | 'rectangle' | 'circle' | 'arrow'
export type FillStyle = 'solid' | 'hachure' | 'cross-hatch'
export type StrokeStyle = 'solid' | 'dashed' | 'dotted'
export type StrokeSharpness = 'sharp' | 'round'

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

export type DrawboardElement =
  | IDrawboardLineElement
  | IDrawboardRectangleElement
  | IDrawboardCircleElement
  | IDrawboardArrowElement
