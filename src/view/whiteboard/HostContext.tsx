import React from 'react'
import type { IWhiteboardHost } from './contracts'

export const EMPTY_HOST: IWhiteboardHost = Object.freeze({})
export const BoardHostContext = React.createContext<IWhiteboardHost>(EMPTY_HOST)
export const useBoardHost = (): IWhiteboardHost => React.useContext(BoardHostContext)
