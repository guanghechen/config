import React from 'react'
import { classes } from '../constant'
import { JsonFieldCopyButton } from '../FieldCopyButton'
import { JsonFieldKey } from '../FieldKey'

interface IProps {
  readonly name: string | number | null
  readonly depth: number
}

export class JsonFieldUndefined extends React.Component<IProps> {
  public static displayName = 'JsonFieldUndefined'

  public override render(): React.ReactElement {
    const { name, depth } = this.props
    const indentStyle: React.CSSProperties = { paddingLeft: `${depth * 1.5}rem` }
    const text: string = 'undefined'

    return (
      <div className={classes.container.line} style={indentStyle}>
        <JsonFieldKey name={name} />
        <span className="italic text-gray-400">{text}</span>
        <JsonFieldCopyButton value={undefined} contentForCopy={text} />
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps): boolean {
    const props: IProps = this.props
    return props.name !== nextProps.name || props.depth !== nextProps.depth
  }
}
