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

export interface IStyle {
  readonly stroke: string
  readonly fill: string
  readonly strokeWidth: number
  readonly roughness: number
  readonly fillPattern?: 'solid' | 'hachure' | 'cross-hatch'
}

interface IElementBase {
  readonly id: string
  readonly groupId?: string
  readonly style: IStyle
}

export type IMarkdownSource =
  | { readonly kind: 'inline'; readonly content: string }
  | { readonly kind: 'file'; readonly filepath: string }

export type INode = IElementBase &
  IBounds &
  (
    | {
        readonly type: 'shape'
        readonly shape: 'rectangle' | 'ellipse' | 'diamond'
        readonly label?: string
      }
    | { readonly type: 'text'; readonly text: string }
    | { readonly type: 'markdown'; readonly source: IMarkdownSource }
    | { readonly type: 'image'; readonly url: string }
    | { readonly type: 'stroke'; readonly points: ReadonlyArray<IPoint> }
  )

export type IEndpoint = IPoint & { readonly nodeId?: string }

export interface IEdge extends IElementBase {
  readonly type: 'edge'
  readonly from: IEndpoint
  readonly to: IEndpoint
  readonly label?: string
}

export type IElement = INode | IEdge
export type ILabelElement = (INode & { readonly type: 'shape' }) | IEdge

export interface IWhiteboardDocument {
  readonly kind: 'yoz.whiteboard'
  readonly schemaVersion: 1
  readonly id: string
  readonly title: string
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
    elements: [],
  }
}
