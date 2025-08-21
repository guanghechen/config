import React from 'react'
import { CopyButton } from '../button/copy'

interface IProps {
  readonly value: unknown
  readonly contentForCopy?: string
  readonly inline?: boolean
}

export class JsonFieldCopyButton extends React.Component<IProps> {
  public static readonly displayName = 'JsonFieldCopyButton'

  public override render(): React.ReactElement {
    const { calcContentForCopy, props } = this
    const { inline = false } = props

    const className = inline
      ? 'invisible ml-2 inline cursor-pointer opacity-60 transition-opacity duration-200 hover:opacity-100 group-hover:visible'
      : 'invisible ml-2 inline cursor-pointer opacity-60 transition-opacity duration-200 hover:opacity-100 group-hover:visible'

    return (
      <span className={className}>
        <CopyButton calcContentForCopy={calcContentForCopy} />
      </span>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps): boolean {
    const props: IProps = this.props
    return props.value !== nextProps.value || props.inline !== nextProps.inline
  }

  public calcContentForCopy = (): string => {
    const { value, contentForCopy } = this.props
    return contentForCopy ?? JSON.stringify(value, null, 2)
  }
}
