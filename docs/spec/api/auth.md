# JWT Authentication

## API

### POST /api/user/auth

**Request:**
```json
{
  "authToken": "string"
}
```

**Response (200):**
```json
{
  "data": {
    "success": true,
    "token": "jwt_token_string",
    "expiresIn": "7d"
  }
}
```

**Response (403):**
```json
{
  "error": "Invalid authentication token"
}
```

## Implementation

### Server
- Environment: `YOZ_AUTH_TOKEN`, `YOZ_JWT_SECRET`
- Token verification: compare provided token with `YOZ_AUTH_TOKEN`
- JWT expires in 7 days, contains authentication flag
- All `/api/*` endpoints except `/api/user/auth` require Bearer token or authentication cookie
- Return 403 for missing/invalid tokens
- Auth endpoint sets HTTP-only cookie and returns JWT token in response body

### Client
- Store JWT token in `localStorage` as `auth_token`
- Use `authenticatedFetch` for protected API calls
- 403 responses trigger login popup with 300ms debounce
- Single popup policy using `signed` state
- Page refresh after successful login to retrigger API calls
