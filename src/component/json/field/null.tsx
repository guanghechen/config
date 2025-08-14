import React from 'react'
import { classes } from '../constant'
import { JsonFieldCopyButton } from '../FieldCopyButton'
import { JsonFieldKey } from '../FieldKey'

interface IProps {
  readonly name: string | number | null
  readonly depth: number
}

export class JsonFieldNull extends React.Component<IProps> {
  public static displayName = 'JsonFieldNull'

  public override render(): React.ReactElement {
    const { name, depth } = this.props
    const indentStyle: React.CSSProperties = { paddingLeft: `${depth * 1.5}rem` }
    const text: string = 'null'

    return (
      <div className={classes.container.line} style={indentStyle}>
        <JsonFieldKey name={name} />
        <span className="font-medium text-cyan-600 dark:text-cyan-400">{text}</span>
        <JsonFieldCopyButton value={null} contentForCopy={text} />
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps): boolean {
    const props: IProps = this.props
    return props.name !== nextProps.name || props.depth !== nextProps.depth
  }
}
