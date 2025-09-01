# JWT Authentication

## API

### POST /api/user/login

**Request:**
```json
{
  "username": "string",
  "password": "string"
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
  "error": "Invalid credentials"
}
```

## Implementation

### Server
- Environment: `YOZ_USERNAME`, `YOZ_PASSWORD` (SHA1 hashed), `JWT_SECRET`
- Password verification: hash user input with SHA1, compare with `YOZ_PASSWORD`
- JWT expires in 7 days, contains username
- All `/api/*` endpoints except `/api/user/login` require Bearer token or authentication cookie
- Return 403 for missing/invalid tokens
- Login endpoint sets HTTP-only cookie and returns token in response body

### Client
- Store token in `localStorage` as `auth_token`
- Use `authenticatedFetch` for protected API calls
- 403 responses trigger login popup with 300ms debounce
- Single popup policy using `signed` state
- Page refresh after successful login to retrigger API calls
- Timing attack prevention: check username and password together
