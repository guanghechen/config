import React from 'react'
import { classes } from '../constant'
import { JsonFieldCopyButton } from '../FieldCopyButton'
import { JsonFieldKey } from '../FieldKey'

interface IProps {
  readonly name: string | number | null
  readonly value: symbol
  readonly depth: number
}

export class JsonFieldSymbol extends React.Component<IProps> {
  public static displayName = 'JsonFieldSymbol'

  public override render(): React.ReactElement {
    const { name, value, depth } = this.props
    const indentStyle: React.CSSProperties = { paddingLeft: `${depth * 1.5}rem` }
    const text: string = `Symbol(${value.description ? `"${value.description}"` : ''})`

    return (
      <div className={classes.container.line} style={indentStyle}>
        <JsonFieldKey name={name} />
        <span className="font-medium text-yellow-500 dark:text-yellow-400">{text}</span>
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
