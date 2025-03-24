import React from 'react'

interface IProps {
  readonly name: string | number | null
}

export class JsonFieldKey extends React.Component<IProps> {
  public static displayName = 'JsonFieldKey'

  public override render(): React.ReactElement {
    const { name } = this.props

    if (name === null || typeof name === 'number') return <React.Fragment />

    return (
      <span>
        <span className="font-medium">{name}</span>
        <span className="pr-2">:</span>
      </span>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps): boolean {
    const props: IProps = this.props
    return props.name !== nextProps.name
  }
}
