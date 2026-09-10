import React from 'react'
import { LoginModal } from '@/container/LoginModal'
import { ThemeToggle } from '@/container/ThemeToggle'
import { Link } from 'react-router-dom'
import { FolderIcon } from '@/common/component/icon/material'

interface IProps {
  readonly scenario: string
  readonly floating?: React.ReactElement
  readonly menu?: React.ReactElement
  readonly toolbar?: React.ReactElement
  readonly viewActions?: React.ReactElement
  readonly sidebar?: React.ReactElement
  readonly children?: React.ReactNode
}

export class ViewLayout extends React.PureComponent<IProps> {
  public static readonly displayName: string = 'ViewLayout'

  public override render(): React.ReactElement {
    const { scenario, floating, menu, toolbar, viewActions, sidebar, children } = this.props

    return (
      <div className="vl-root" data-scenario={scenario}>
        <div className="vl-topbar">
          {scenario === 'file' && (
            <Link
              to="/ws"
              title="Workspace"
              aria-label="Workspace"
              className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-gray-500 hover:bg-gray-200/60 dark:text-gray-400 dark:hover:bg-gray-700"
            >
              <FolderIcon className="h-4 w-4" />
            </Link>
          )}
          {menu && <div className="vlt-left">{menu}</div>}
          <div className="vlt-middle">{toolbar}</div>
          <div className="vlt-right">{viewActions}</div>
          <div className="vlt-rightest">
            <ThemeToggle />
          </div>
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
