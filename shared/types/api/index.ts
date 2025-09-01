// Union types for all API interfaces
import type {
  IFileSaveRequestParams,
  IFileSaveRequestPayload,
  IFileSaveResponseResult,
} from './file'
import type {
  ITransformerListRequestParams,
  ITransformerListRequestPayload,
  ITransformerListResponseResult,
  ITransformerResolveRequestParams,
  ITransformerResolveRequestPayload,
  ITransformerResolveResponseResult,
  ITransformerSaveRequestParams,
  ITransformerSaveRequestPayload,
  ITransformerSaveResponseResult,
} from './transform'
import type {
  IUserLoginRequestParams,
  IUserLoginRequestPayload,
  IUserLoginResponseResult,
  IUserLogoutRequestParams,
  IUserLogoutRequestPayload,
  IUserLogoutResponseResult,
  IUserProfileRequestParams,
  IUserProfileRequestPayload,
  IUserProfileResponseResult,
} from './user'

export * from './event'
export * from './file'
export * from './transform'
export * from './user'

export type IRequestParams =
  | IFileSaveRequestParams
  | IUserLoginRequestParams
  | IUserLogoutRequestParams
  | IUserProfileRequestParams
  | ITransformerListRequestParams
  | ITransformerResolveRequestParams
  | ITransformerSaveRequestParams

export type IRequestPayload =
  | IFileSaveRequestPayload
  | IUserLoginRequestPayload
  | IUserLogoutRequestPayload
  | IUserProfileRequestPayload
  | ITransformerListRequestPayload
  | ITransformerResolveRequestPayload
  | ITransformerSaveRequestPayload

export type IResponseResult =
  | IFileSaveResponseResult
  | IUserLoginResponseResult
  | IUserLogoutResponseResult
  | IUserProfileResponseResult
  | ITransformerListResponseResult
  | ITransformerResolveResponseResult
  | ITransformerSaveResponseResult
