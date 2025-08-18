import React from 'react'
import { MultiInput } from '@/component/MultiInput'
import type { IChainPath } from '../context'
import { getPathColorClasses } from '../utils'

export type DisplayMode = 'inline' | 'lines'

interface IProps {
  chainPaths: IChainPath[]
  onChange: (chainPaths: IChainPath[]) => void
  placeholder?: string
  displayMode: DisplayMode
  onDisplayModeChange: (mode: DisplayMode) => void
}

export const MultiPathInput: React.FC<IProps> = ({
  chainPaths,
  onChange,
  placeholder = 'Add JSON paths for transform nodes (e.g., .data.type)',
  displayMode,
  onDisplayModeChange,
}) => {
  const createChainPath = React.useCallback((value: string): IChainPath => {
    return { path: value, value, visible: true }
  }, [])

  const getChainPathColorClasses = React.useCallback(
    (chainPath: IChainPath, allChainPaths: IChainPath[]): string => {
      const allPaths = allChainPaths.map(cp => cp.path)
      return getPathColorClasses(chainPath.path, allPaths)
    },
    [],
  )

  const renderChainPathContent = React.useCallback((chainPath: IChainPath): React.ReactNode => {
    return chainPath.path
  }, [])

  return (
    <MultiInput
      items={chainPaths}
      onChange={onChange}
      placeholder={placeholder}
      displayMode={displayMode}
      onDisplayModeChange={onDisplayModeChange}
      createItem={createChainPath}
      getItemColorClasses={getChainPathColorClasses}
      renderItemContent={renderChainPathContent}
      allowDuplicates={false}
    />
  )
}

MultiPathInput.displayName = 'TextViewMultiPathInput'