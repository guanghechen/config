export interface IPoint {
  readonly x: number
  readonly y: number
}

export interface IBounds extends IPoint {
  readonly width: number
  readonly height: number
}

export interface ICamera extends IPoint {
  readonly zoom: number
}

export interface IRegion extends IBounds {
  readonly id: string
  readonly name: string
}

export interface IStyle {
  readonly stroke: string
  readonly fill: string
  readonly strokeWidth: number
  readonly roughness: number
  readonly fillPattern?: 'solid' | 'hachure' | 'cross-hatch'
  readonly fontSize?: number
  readonly fontFamily?: 'hand' | 'sans' | 'mono'
  readonly fontWeight?: 'normal' | 'bold'
  readonly textAlign?: 'left' | 'center' | 'right'
}

interface IElementBase {
  readonly id: string
  readonly groupId?: string
  readonly style: IStyle
  readonly locked?: boolean
  readonly hidden?: boolean
}

export type IMarkdownSource =
  | { readonly kind: 'inline'; readonly content: string }
  | { readonly kind: 'file'; readonly filepath: string }

export type INode = IElementBase &
  IBounds & {
    readonly rotation?: number
    readonly flipX?: boolean
    readonly flipY?: boolean
  } & (
    | {
        readonly type: 'shape'
        readonly shape: 'rectangle' | 'ellipse' | 'diamond'
        readonly label?: string
        readonly autoSize?: boolean
      }
    | { readonly type: 'text'; readonly text: string; readonly autoSize?: boolean }
    | { readonly type: 'markdown'; readonly source: IMarkdownSource }
    | { readonly type: 'image'; readonly url: string }
    | { readonly type: 'stroke'; readonly points: ReadonlyArray<IPoint> }
  )

export type IEndpoint = IPoint & { readonly nodeId?: string }
export type IEdgeRouting = 'straight' | 'polyline' | 'curve'
export type IArrowhead = 'none' | 'arrow'

export interface IEdge extends IElementBase {
  readonly type: 'edge'
  readonly from: IEndpoint
  readonly to: IEndpoint
  readonly label?: string
  readonly routing?: IEdgeRouting
  readonly controls?: ReadonlyArray<IPoint>
  readonly arrowStart?: IArrowhead
  readonly arrowEnd?: IArrowhead
  readonly lineStyle?: 'solid' | 'dashed' | 'dotted'
}

export type IEdgeAppearance = Pick<IEdge, 'routing' | 'arrowStart' | 'arrowEnd' | 'lineStyle'>
export const DEFAULT_EDGE_APPEARANCE: Required<IEdgeAppearance> = {
  routing: 'straight',
  arrowStart: 'none',
  arrowEnd: 'arrow',
  lineStyle: 'solid',
}

export type IElement = INode | IEdge
export type ILabelElement = (INode & { readonly type: 'shape' }) | IEdge

// Back to front: connections, drawings, rich-content cards.
export function elementLayer(element: IElement): 0 | 1 | 2 {
  if (element.type === 'edge') return 0
  return element.type === 'markdown' || element.type === 'image' ? 2 : 1
}

export interface IWhiteboardDocument {
  readonly kind: 'yoz.whiteboard'
  readonly schemaVersion: 1
  readonly id: string
  readonly title: string
  readonly stacking?: 'document'
  readonly regions?: ReadonlyArray<IRegion>
  readonly presentation?: ReadonlyArray<string>
  readonly elements: ReadonlyArray<IElement>
}

export const DEFAULT_STYLE: IStyle = {
  stroke: 'theme:ink',
  fill: 'theme:paper',
  strokeWidth: 2,
  roughness: 2,
}

export function createDocument(): IWhiteboardDocument {
  return {
    kind: 'yoz.whiteboard',
    schemaVersion: 1,
    id: crypto.randomUUID(),
    title: 'Untitled whiteboard',
    stacking: 'document',
    elements: [],
  }
}
