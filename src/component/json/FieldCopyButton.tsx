import React from 'react'
import { CopyButton } from '../CopyButton'

interface IProps {
  readonly value: unknown
  readonly contentForCopy?: string
}

export class JsonFieldCopyButton extends React.Component<IProps> {
  public static readonly displayName = 'JsonFieldCopyButton'

  public override render(): React.ReactElement {
    const { calcContentForCopy } = this
    return (
      <span className="invisible ml-2 inline cursor-pointer opacity-60 transition-opacity duration-200 hover:opacity-100 group-hover:visible">
        <CopyButton calcContentForCopy={calcContentForCopy} />
      </span>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps): boolean {
    const props: IProps = this.props
    return props.value !== nextProps.value
  }

  public calcContentForCopy = (): string => {
    const { value, contentForCopy } = this.props
    return contentForCopy ?? JSON.stringify(value, null, 2)
  }
}
