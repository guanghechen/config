import type { LogLevel } from '../enum/reporter'
import type { Mutable } from './common'

export interface IServerSettings {
  readonly loglevel: LogLevel
}

export type IMutableServerSettings = Mutable<IServerSettings>
