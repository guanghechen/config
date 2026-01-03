import type { LogLevel } from '../enum/reporter'
import type { IMutable } from './common'

export interface IServerSettings {
  readonly loglevel: LogLevel
}

export type IMutableServerSettings = IMutable<IServerSettings>
