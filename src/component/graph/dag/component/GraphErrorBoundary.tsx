import React from 'react'

interface IState {
  hasError: boolean
  error?: Error
}

interface IProps {
  children: React.ReactNode
}

export class GraphErrorBoundary extends React.Component<IProps, IState> {
  public static readonly displayName: string = 'GraphErrorBoundary'

  constructor(props: IProps) {
    super(props)
    this.state = { hasError: false }
  }

  public static getDerivedStateFromError(error: Error): IState {
    return { hasError: true, error }
  }

  public componentDidCatch(error: Error, errorInfo: React.ErrorInfo): void {
    console.error('Graph rendering error:', error, errorInfo)
  }

  public render(): React.ReactNode {
    if (this.state.hasError) {
      return (
        <div className="flex items-center justify-center h-full">
          <div className="text-center">
            <div className="text-red-500 text-lg font-semibold mb-2">Graph Rendering Error</div>
            <div className="text-gray-600 dark:text-gray-400 text-sm">
              {this.state.error?.message || 'An unexpected error occurred'}
            </div>
          </div>
        </div>
      )
    }

    return this.props.children
  }
}
