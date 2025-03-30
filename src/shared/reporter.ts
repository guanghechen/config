import { LogLevel, LogLevelPriority } from './enum/reporter'

interface IReporterProps {
  readonly name: string
  readonly subject?: string
  readonly date?: boolean
  readonly getLevel?: () => LogLevel
}

const lglevel2priority: Record<LogLevel, LogLevelPriority> = {
  [LogLevel.DEBUG]: LogLevelPriority.DEBUG,
  [LogLevel.VERBOSE]: LogLevelPriority.VERBOSE,
  [LogLevel.INFO]: LogLevelPriority.INFO,
  [LogLevel.WARN]: LogLevelPriority.WARN,
  [LogLevel.ERROR]: LogLevelPriority.ERROR,
}

const formatTitle = (name: string, subject: string): string =>
  subject ? `[${name}] ${subject}` : `[${name}]`

export class Reporter {
  private name: string
  private subject: string
  private title: string
  private readonly showDate: boolean
  private readonly getLevelPriority: () => LogLevelPriority

  constructor(props: IReporterProps) {
    const { name } = props
    const subject: string = props.subject || ''
    const showDate: boolean = !!props.date
    const getLevel: () => LogLevel = props.getLevel || (() => LogLevel.DEBUG)
    const getLevelPriority: () => LogLevelPriority = () => {
      const level: LogLevel = getLevel()
      return lglevel2priority[level]
    }

    const title: string = formatTitle(name, subject)

    this.name = name
    this.subject = subject
    this.title = title
    this.showDate = showDate
    this.getLevelPriority = getLevelPriority
  }

  public static resolveLogLevel(level: string): LogLevel | null {
    switch (level.toUpperCase()) {
      case LogLevel.DEBUG:
        return LogLevel.DEBUG
      case LogLevel.VERBOSE:
        return LogLevel.VERBOSE
      case LogLevel.INFO:
        return LogLevel.INFO
      case LogLevel.WARN:
        return LogLevel.WARN
      case LogLevel.ERROR:
        return LogLevel.ERROR
      default:
        return null
    }
  }

  public setName(name: string): void {
    this.name = name
    this.title = formatTitle(name, this.subject)
  }

  public setSubject(subject: string): void {
    this.subject = subject
    this.title = formatTitle(this.name, subject)
  }

  public debug(...args: unknown[]): void {
    const level: LogLevelPriority = this.getLevelPriority()

    if (level <= LogLevelPriority.DEBUG) {
      const title: string = this.formatTitle()
      console.debug(title, ...args)
    }
  }

  public log(...args: unknown[]): void {
    const level: LogLevelPriority = this.getLevelPriority()
    if (level <= LogLevelPriority.VERBOSE) {
      const title: string = this.formatTitle()
      console.log(title, ...args)
    }
  }

  public info(...args: unknown[]): void {
    const level: LogLevelPriority = this.getLevelPriority()
    if (level <= LogLevelPriority.INFO) {
      const title: string = this.formatTitle()
      console.info(title, ...args)
    }
  }

  public warn(...args: unknown[]): void {
    const level: LogLevelPriority = this.getLevelPriority()
    if (level <= LogLevelPriority.WARN) {
      const title: string = this.formatTitle()
      console.warn(title, ...args)
    }
  }

  public error(...args: unknown[]): void {
    const level: LogLevelPriority = this.getLevelPriority()
    if (level <= LogLevelPriority.ERROR) {
      const title: string = this.formatTitle()
      console.error(title, ...args)
    }
  }

  public formatTitle(): string {
    if (!this.showDate) return this.title

    const now = new Date()
    const hour: string = now.getHours().toString().padStart(2, '0')
    const minute: string = now.getMinutes().toString().padStart(2, '0')
    const second: string = now.getSeconds().toString().padStart(2, '0')
    const millisecond: string = now.getMilliseconds().toString().padStart(3, '0')
    const time: string = `${hour}:${minute}:${second}.${millisecond}`
    return `${time} ${this.title}`
  }
}
