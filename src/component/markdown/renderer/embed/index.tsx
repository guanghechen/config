import isEqual from '@guanghechen/equal'
import React from 'react'
import type { ICodeMetaData } from '@/util/parseCodeMeta'

const EmbedMath = React.lazy(() => import('./math'))
const EmbedMermaid = React.lazy(() => import('./mermaid'))
const EmbedMarkdown = React.lazy(() => import('./markdown'))
const EmbedExcalidraw = React.lazy(() => import('./excalidraw'))
const EmbedDrawboard = React.lazy(() => import('./drawboard'))

interface IProps {
  readonly code: string
  readonly lang: string
  readonly meta: ICodeMetaData
}

export class Embed extends React.Component<IProps> {
  public static readonly displayName = 'Embed'

  public override render(): React.ReactElement {
    const { lang, code } = this.props

    switch (lang.toLowerCase()) {
      case 'math':
        return <EmbedMath code={code} />
      case 'mermaid':
        return <EmbedMermaid code={code} />
      case 'markdown':
        return <EmbedMarkdown code={code} />
      case 'excalidraw':
        return <EmbedExcalidraw code={code} />
      case 'drawboard':
        return <EmbedDrawboard code={code} />
      default:
        return <React.Fragment />
    }
  }

  public override shouldComponentUpdate(nextProps: Readonly<IProps>): boolean {
    const props = this.props
    return (
      props.code !== nextProps.code ||
      props.lang.toLowerCase() !== nextProps.lang.toLowerCase() ||
      !isEqual(props.meta, nextProps.meta)
    )
  }
}
