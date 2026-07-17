export enum TsukiEventNameEnum {
  FOCUS_ME = '@tsuki/focus_me',
  FILE_SWITCH = '@tsuki/file_switch',
}

export enum TsukiContentEventNameEnum {
  PAGE_STATUS = '@tsuki/page_status',
}

export enum TsukiTargetEnum {
  BROADCAST = '@@tsuki-broad@@',
  CURRENT = '@@tsuki-current@@',
}

export enum TsukiEventResponseCodeEnum {
  SUCCEED = 200,
  BAD_REQUEST = 400,
  FORBIDDEN = 403,
  SERVER_ERROR = 500,
  UNKNOWN = 0,
}
