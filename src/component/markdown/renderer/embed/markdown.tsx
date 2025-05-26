import React from 'react'
import { ReactMarkdownContent } from '../../ReactMarkdownContent'

interface IProps {
  readonly code: string
}

class Markdown extends React.Component<IProps> {
  public static displayName = 'CodeRendererMarkdown'

  public override render(): React.ReactElement {
    const { code } = this.props
    return <ReactMarkdownContent content={code} />
  }

  public override shouldComponentUpdate(nextProps: Readonly<IProps>): boolean {
    const props = this.props
    return props.code !== nextProps.code
  }
}

export default Markdown
