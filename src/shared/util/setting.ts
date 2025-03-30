import { LogLevel } from '../enum/reporter'
import { Reporter } from '../reporter'
import type { IMutableServerSettings, IServerSettings } from '../types/setting'

interface ISettingsResolver<T> {
  readonly defaults: () => T
  readonly normalize: (rawSettings?: unknown) => T
}

export const serverSettingsResolver: ISettingsResolver<IServerSettings> = {
  defaults: (): IServerSettings => {
    return {
      loglevel: LogLevel.DEBUG,
    }
  },
  normalize: (rawSettings?: unknown): IServerSettings => {
    const settings: IMutableServerSettings = serverSettingsResolver.defaults()
    if (!rawSettings || typeof rawSettings !== 'object') return settings

    // For type assertion.
    const rs = rawSettings as IServerSettings

    // Resolve the loglevel.
    if (typeof rs.loglevel === 'string') {
      settings.loglevel = Reporter.resolveLogLevel(rs.loglevel) ?? settings.loglevel
    }

    return settings
  },
}
