import type { IWhiteboardRuntimeOptions } from './WhiteboardRuntime'
import { WhiteboardRuntime } from './WhiteboardRuntime'

export const createWhiteboardRuntime = (
  options: IWhiteboardRuntimeOptions = {},
): WhiteboardRuntime => {
  return new WhiteboardRuntime(options)
}
