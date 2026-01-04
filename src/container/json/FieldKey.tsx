import React from 'react'

interface IProps {
  readonly name: string | number | null
  readonly children?: React.ReactNode
}

export class JsonFieldKey extends React.Component<IProps> {
  public static displayName = 'JsonFieldKey'

  public override render(): React.ReactElement {
    const { name, children } = this.props

    if (name === null || typeof name === 'number') return <React.Fragment />

    return (
      <span className="flex items-center whitespace-nowrap">
        <span className="font-medium text-gray-900 dark:text-gray-100">{name}</span>
        <span className="pr-2 text-gray-900 dark:text-gray-100">:</span>
        {children}
      </span>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps): boolean {
    const props: IProps = this.props
    return props.name !== nextProps.name || props.children !== nextProps.children
  }
}
