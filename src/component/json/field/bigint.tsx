import React from 'react'
import { classes } from '../constant'
import { JsonFieldCopyButton } from '../FieldCopyButton'
import { JsonFieldKey } from '../FieldKey'

interface IProps {
  readonly name: string | number | null
  readonly value: bigint
  readonly depth: number
}

export class JsonFieldBigint extends React.Component<IProps> {
  public static displayName = 'JsonFieldBigint'

  public override render(): React.ReactElement {
    const { name, value, depth } = this.props
    const indentStyle: React.CSSProperties = { paddingLeft: `${depth * 1.5}rem` }
    const text: string = value.toString()

    return (
      <div className={classes.container.line} style={indentStyle}>
        <JsonFieldKey name={name} />
        <span className="font-medium text-indigo-600 dark:text-indigo-400">{text}n</span>
        <JsonFieldCopyButton value={value} contentForCopy={text} />
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps): boolean {
    const props: IProps = this.props
    return (
      props.name !== nextProps.name ||
      props.value !== nextProps.value ||
      props.depth !== nextProps.depth
    )
  }
}
