import React from 'react'
import { classes } from '../constant'
import { JsonFieldCopyButton } from '../FieldCopyButton'
import { JsonFieldKey } from '../FieldKey'

interface IProps {
  readonly name: string | number | null
  // eslint-disable-next-line @typescript-eslint/no-unsafe-function-type
  readonly value: Function
  readonly depth: number
}

export class JsonFieldFunction extends React.Component<IProps> {
  public static displayName = 'JsonFieldFunction'

  public override render(): React.ReactElement {
    const { name, value, depth } = this.props
    const indentStyle: React.CSSProperties = { paddingLeft: `${depth * 1.5}rem` }

    const text: string = value.toString()
    const match = text.match(/(?:function.*?\(|(?:\((?=.*=>)))(.*?)(?:\))/s)
    const args: string = match && match[1] ? match[1].trim() : ''

    return (
      <div className={classes.container.line} style={indentStyle}>
        <JsonFieldKey name={name} />
        <span className="pr-1 font-medium text-blue-600 dark:text-blue-400">ƒ</span>
        <span className="text-blue-400 dark:text-blue-300">({args})</span>
        <span className="italic text-gray-500 dark:text-gray-400"> =&gt; &#123;...&#125;</span>
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
