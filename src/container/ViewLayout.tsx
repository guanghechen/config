import React from 'react'
import { LoginModal } from '@/container/LoginModal'
import { Settings } from '@/container/Settings'

interface IProps {
  readonly scenario: string
  readonly floating?: React.ReactElement
  readonly menu?: React.ReactElement
  readonly toolbar?: React.ReactElement
  readonly sidebar?: React.ReactElement
  readonly children?: React.ReactNode
}

export class ViewLayout extends React.PureComponent<IProps> {
  public static readonly displayName: string = 'ViewLayout'

  public override render(): React.ReactElement {
    const { scenario, floating, menu, toolbar, sidebar, children } = this.props

    return (
      <div className="vl-root" data-scenario={scenario}>
        <div className="vl-topbar">
          <div className="vlt-leftest">
            <Settings />
          </div>
          {menu && <div className="vlt-left">{menu}</div>}
          <div className="vlt-middle">{toolbar}</div>
          <div className="vlt-right" />
          <div className="vlt-rightest" />
        </div>
        {sidebar && <div className="vl-sidebar">{sidebar}</div>}
        <div className="vl-main">{children}</div>
        <div className="vl-floating">
          <React.Fragment>
            {floating}
            <LoginModal />
          </React.Fragment>
        </div>
      </div>
    )
  }
}
