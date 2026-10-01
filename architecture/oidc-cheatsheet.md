# Citizen sign-in: OIDC cheatsheet

How Defra Forms signs citizens in, and what each OpenID Connect (OIDC) setting does and why it is set that way.

The step-by-step sequence diagrams are in the LikeC4 model, in the **Auth** folder:

- OIDC sign-in (authorization code + PKCE)
- OIDC token refresh
- OIDC sign-out and token revocation

## Contents

- [Parties](#parties)
- [The flow in one paragraph](#the-flow-in-one-paragraph)
- [Authorization request parameters](#authorization-request-parameters)
- [state, nonce and PKCE](#state-nonce-and-pkce)
- [Client authentication: private_key_jwt](#client-authentication-private_key_jwt)
- [Signing and keys](#signing-and-keys)
- [Scopes and claims](#scopes-and-claims)
- [Resource indicator and the access token](#resource-indicator-and-the-access-token)
- [Tokens and lifetimes](#tokens-and-lifetimes)
- [Refresh](#refresh)
- [Sign-out and revocation](#sign-out-and-revocation)
- [Interactions (forms-identity-ui)](#interactions-forms-identity-ui)
- [Provider endpoints](#provider-endpoints)
- [Cookies and sessions](#cookies-and-sessions)
- [Provider storage (identity API)](#provider-storage-identity-api)
- [Resource server checks (forms-submission-api)](#resource-server-checks-forms-submission-api)
- [Configuration reference](#configuration-reference)
- [Specifications](#specifications)

## Parties

| Party | OIDC role | What it does |
|---|---|---|
| Citizen's browser | User agent | Carries redirects between the runner and the provider. It never holds a token. |
| **forms-runner** | Relying party (RP), confidential client `runner` | Starts sign-in and sign-out, swaps the code for tokens, refreshes and revokes them, and keeps them in its server-side session. Uses `openid-client` v6. |
| **forms-identity-ui** | OpenID provider (OP), the issuer | Runs `oidc-provider` 9.x in-process, and shows the GOV.UK sign-in pages (the "interactions"). It keeps no data of its own, so that the internet-facing service holds no database; the data sits behind identity API. |
| **forms-identity-api** | Store for the provider (not an OIDC party) | Holds accounts, one-time codes, and every provider session, grant, code and refresh token. Only identity UI can call it. |
| **forms-submission-api** | Resource server | Accepts the citizen access token, and returns only the records owned by that citizen. |

The runner is the only registered client. Sign-in is on only where `USE_SIGN_IN_FEATURE` is set in forms-runner.

## The flow in one paragraph

The runner uses the **authorization code flow with PKCE**:

1. It redirects the citizen to the provider's `/auth` with `state`, `nonce` and a PKCE challenge.
2. The provider runs its interactions: email, one-time code, and a mobile number the first time. It grants consent without a page, then redirects back with a one-time code.
3. The runner swaps the code at `/token`, and proves who it is with a signed assertion (`private_key_jwt`). It gets:
   - an ID token (who the citizen is)
   - an access token for the submission API
   - a refresh token, whose lifetime is fixed from sign-in
4. At sign-out, the runner sends the citizen to `/session/end`. When the citizen comes back, the runner revokes the refresh token at `/token/revocation`.

## Authorization request parameters

The runner's `/auth/sign-in` route (`forms-runner` `src/server/routes/auth.js`) builds these query parameters and redirects the browser to the provider's `GET /auth`. The request goes through the browser rather than server to server, so that:

- the citizen signs in on the provider's own pages, and only the provider sees the email address and the one-time code
- the provider can set and read its own cookies in the citizen's browser
- only a short-lived, single-use code comes back through the browser; the runner swaps it for tokens server to server at `/token`, so tokens never pass through the browser

| Parameter | Value | Why |
|---|---|---|
| `response_type` | `code` | Authorization code flow, so tokens never pass through the browser. It is the only response type the provider allows. |
| `client_id` | `runner` | The one registered client. |
| `redirect_uri` | `{runner}/auth/callback` | Must match a URI in `OIDC_RUNNER_REDIRECT_URIS` exactly. The runner builds it from config, not from the request, so a proxy cannot change it. |
| `scope` | `openid email offline_access` | `openid` gives an ID token with `sub`. `email` adds the `email` claim. `offline_access` asks for a refresh token (see [Scopes and claims](#scopes-and-claims)). |
| `prompt` | `login consent` | `login` means a code is asked for on every sign-in: the provider does not sign the citizen in again from its own session. This is so that every new runner session starts with proof of the email address, even while an earlier provider session is still open. `consent` is required for the provider to accept `offline_access` (OIDC Core §11). |
| `resource` | The submission API's resource indicator (`OIDC_SUBMISSION_API_RESOURCE`) | Resource indicator (RFC 8707). It makes the access token a JWT with that audience (see [Resource indicator](#resource-indicator-and-the-access-token)). |
| `state` | Random, one per sign-in | Stops login CSRF (see the next table). |
| `nonce` | Random, one per sign-in | Binds the ID token to this sign-in. |
| `code_challenge` | `BASE64URL(SHA256(code_verifier))` | PKCE. |
| `code_challenge_method` | `S256` | The only PKCE method the provider accepts. It requires PKCE for every request, although the runner also authenticates with a key: PKCE also stops an attacker from injecting a stolen code into the runner's callback. |

## state, nonce and PKCE

All three are random values that the runner makes for each sign-in. It saves them in its server-side session as the "sign-in transaction", together with `returnUrl`. Each defends against a different attack:

| Value | Sent | Comes back | Checked by | Stops |
|---|---|---|---|---|
| `state` | On `/auth` | As a query parameter on `/auth/callback` | Runner: must equal the session value, else 403 | Login CSRF: an attacker's code landing in the citizen's browser. |
| `nonce` | On `/auth` | As the `nonce` claim in the ID token | Runner (openid-client) at the code exchange | ID token injection: an ID token from another sign-in, even one issued to `runner`, being accepted in this one. |
| `code_verifier` | Only at `/token`, never through the browser | Not returned | Provider: `SHA256(code_verifier)` must equal the stored `code_challenge` | Code interception: a stolen code is useless without the verifier. |

The runner clears the transaction after one callback attempt, pass or fail, so each sign-in gets new values.

## Client authentication: private_key_jwt

The runner proves who it is at `/token` and `/token/revocation` with a **signed JWT assertion** (RFC 7523), not a client secret.

- **Keys:** the runner holds the private RSA key (`OIDC_CLIENT_PRIVATE_JWK`). The provider holds only the public half (`OIDC_RUNNER_JWKS`), so nothing the provider stores can pretend to be the runner.
- **Algorithm:** the assertion is signed with RS256. Its `kid` header selects the public key, so the provider can hold two keys while one rotates.
- **Assertion claims:** `iss` = `sub` = `runner`, `aud` = the provider, a short `exp`, and a unique `jti`.
- **Replay detection:** the provider records each `jti` in the `replay_detection` store. An assertion used a second time is refused.
- **Other methods:** the provider accepts no other client authentication method, including at the revocation endpoint.

## Signing and keys

| Artefact | Algorithm | Signed by | Verified by |
|---|---|---|---|
| ID token | RS256 | Provider (`OIDC_JWKS`) | Runner checks the claims `iss`, `aud`, `exp` and `nonce`. It does not check the signature, which OIDC Core §3.1.3.7 allows for an ID token received directly from the token endpoint over TLS. The provider checks the signature when the ID token comes back as `id_token_hint`. |
| Access token (JWT) | RS256 | Provider (`OIDC_JWKS`) | Submission API, against the provider `/jwks`. |
| Client assertion | RS256 | Runner (`OIDC_CLIENT_PRIVATE_JWK`) | Provider, against `OIDC_RUNNER_JWKS`. |
| Service token (identity UI to identity API) | RS256 | AWS STS | Identity API, against the STS JWKS. |

The provider publishes only RS256 in discovery. The public signing keys are at `/jwks`. `node scripts/generate-jwks.mjs` in forms-identity-ui makes the key sets.

## Scopes and claims

| Scope | Gives |
|---|---|
| `openid` | An ID token, and the `sub` claim (the account id, a UUID). |
| `email` | The `email` claim, in the ID token. |
| `offline_access` | A refresh token, and a grant that stays after sign-out. The provider issues a refresh token only for this scope with `prompt=consent`. |

The access token carries no scopes (`scope: ''`). The submission API filters data by `sub`, so scopes are not needed.

The email is in the **ID token**, not taken from `/me` (userinfo). An access token bound to a resource cannot call userinfo.

## Resource indicator and the access token

- **Why the runner sends `resource`:** it names the API the access token is for (RFC 8707). The runner sends it on **both** the authorization request and the token request. With `resource` only at the token request, the provider returns an opaque token and no error.
- **Allowed resources:** the provider checks `resource` against `OIDC_RESOURCE_SERVERS`. An unknown value gets `invalid_target`.
- **Token format:** the access token is a short-lived **JWT**, RS256. Its `aud` is the resource and its `sub` is the account id. A JWT lets the submission API check the token itself against `/jwks`, with no call to the provider on each request.
- **Storage:** JWT access tokens are **not stored** by the provider. So they cannot be revoked, and one issued before sign-out works until it expires (`OIDC_TTL_ACCESS_TOKEN`).
- **Runner:** the runner never reads the access token. It works out the expiry from `expires_in`.

## Tokens and lifetimes

| Artefact | Lifetime rule | Setting | Stored in | Notes |
|---|---|---|---|---|
| Authorization code | Short; single use | `OIDC_TTL_AUTHORIZATION_CODE` | Identity API | Single use. Using it a second time revokes the whole grant, because a used code that comes back is a sign that it was stolen (RFC 6749 §4.1.2). |
| ID token | Short | `OIDC_TTL_ID_TOKEN` | Runner session | The runner keeps it as `id_token_hint` for sign-out. |
| Access token | Short; the longest an access token works after sign-out | `OIDC_TTL_ACCESS_TOKEN` | Runner session only | JWT, not stored by the provider. |
| Refresh token | **Fixed from sign-in** | `OIDC_TTL_REFRESH_TOKEN` | Identity API and runner session | No rotation, so the expiry never moves. |
| Grant | At least as long as the refresh token | `OIDC_TTL_GRANT` | Identity API | The consent record that the tokens hang from. A refresh fails once its grant has expired. |
| Provider session | Rolling: renewed on each request to the provider | `OIDC_TTL_SESSION` | Identity API | Signs the citizen in to the identity UI account pages. It does not skip login for the runner, because of `prompt=login`. |
| Interaction | Fixed from the start of `/auth` | `OIDC_TTL_INTERACTION` | Identity API | How long the citizen has to finish the sign-in pages. |
| Runner session | **Rolling** idle timeout | `SESSION_TIMEOUT` (ms) | Runner Redis | See below. |
| One-time code | Expires, and is spent after a set number of wrong tries | `OTP_TTL_SECONDS`, `OTP_MAX_ATTEMPTS` | Identity API | Stored as an argon2 hash, so that a database read does not show a code that still works. |
| Code lockout | More than `OTP_LOCKOUT_MAX_REQUESTS` requests within `OTP_LOCKOUT_WINDOW_SECONDS` lock the address for `OTP_LOCKOUT_DURATION_SECONDS` | `OTP_LOCKOUT_*` | Identity API (`otp-lockouts`) | Stops code flooding and guessing. Counted per email address, so that starting a new sign-in does not reset the count. |

**How long a citizen stays signed in.** Two clocks apply, and the shorter one wins:

- **Runner session (rolling):** it starts at `SESSION_TIMEOUT`. Every request that needs the session (not `auth: false`) starts that time again. After `SESSION_TIMEOUT` with no activity the session ends, and the citizen signs in again.
- **Refresh token (fixed):** it lasts `OIDC_TTL_REFRESH_TOKEN` from sign-in, and use does not extend it. A citizen who stays active for longer than that is asked to sign in again: the next refresh gets `invalid_grant`.

## Refresh

- **When:** on each signed-in request, when the access token is within `OIDC_ACCESS_TOKEN_EXPIRY_GRACE_SECONDS` of its expiry. The margin is there so that a token does not expire while a call to the submission API is on its way.
- **The call:** `POST /token` with `grant_type=refresh_token`, the refresh token, the `resource` and a client assertion.
- **The answer:** a new access token and ID token, and the **same** refresh token. The runner checks that the new ID token has the same `sub`, so that a refresh cannot move the session to another account.
- **Why no rotation:** rotation defends against a stolen refresh token. That risk applies to public clients. This client authenticates with a private key, so a refresh token is of no use without that key. Also, with no rotation, two refreshes at the same time cannot conflict.
- **`invalid_grant`:** the refresh token is expired or revoked. The runner clears the identity. Pages that need sign-in then send the citizen to sign in.
- **Any other error:** the runner keeps the session, so that a provider outage does not sign every citizen out; only `invalid_grant` says the sign-in has ended. If the access token has already expired, a page that needs sign-in returns 503.

## Sign-out and revocation

**1. RP-initiated logout.** The runner redirects to `/session/end` with:

| Parameter | Value | Why |
|---|---|---|
| `id_token_hint` | The ID token | Tells the provider who is signing out. The sign-out page submits itself when the hint's `sub` matches the provider session. Otherwise the citizen must press the button, so that a sign-out link from another site cannot sign them out by itself. |
| `client_id` | `runner` | Must match the hint's audience. |
| `post_logout_redirect_uri` | `{runner}/auth/signed-out` | Must be in `OIDC_RUNNER_POST_LOGOUT_REDIRECT_URIS`. Without it, the provider shows its own success page. |
| `state` | JSON `{ slug, previewMode, returnUrl }` | Carries where to go afterwards. It is data, not a CSRF value, so the runner validates it again on return: Bourne rejects `__proto__` keys, so that a changed state cannot reach an object prototype, then Joi checks the shape. |

**2. The provider sign-out page.** It shows the provider's logout form, which carries an `xsrf` value. `POST /session/end/confirm` then:

- ends the provider session and clears its cookie
- **keeps the `offline_access` grant**: oidc-provider does not bind an `offline_access` grant to the session, because offline access is meant to outlive it (OIDC Core §11)
- redirects to `post_logout_redirect_uri?state=…`

**Cancel** goes to the same URI with `cancelled=true`. The runner then keeps the citizen signed in, with the same tokens. This is why the runner keeps the identity and tokens until the citizen comes back, and does not clear them before the redirect to `/session/end`.

**3. Revocation (RFC 7009).** When the citizen comes back, the runner calls `POST /token/revocation` with `token` (the refresh token), `token_type_hint=refresh_token` and a client assertion. The provider then deletes:

- the refresh token
- every stored token and code under its grant
- the grant

The endpoint answers 200, also for an unknown token. The runner clears its session in all cases, even if revocation fails; it logs the error. The citizen asked to sign out, so the runner signs them out; a refresh token left at the provider is of no use without the runner's private key.

Only the refresh token is revoked. The access token is a JWT that the provider cannot revoke, so it expires by itself within `OIDC_TTL_ACCESS_TOKEN`.

## Interactions (forms-identity-ui)

An **interaction** is oidc-provider's name for the part of `/auth` that needs a person: login and consent. The provider stores the interaction, sets a signed `_interaction` cookie, and redirects to `/interaction/{uid}`. After each step, the app calls `interactionFinished`, and the browser goes back to `/auth/{uid}` to resume.

| Step | Route | What happens |
|---|---|---|
| Login prompt | `GET /interaction/{uid}` goes to `/email` | |
| Email | `POST /interaction/{uid}/email` | Identity API issues a code and sends it through Notify, or the address is locked out. |
| Code | `GET` / `POST /interaction/{uid}/code` | Identity API checks the code. An existing account is signed in; a new email is asked for a phone number. Expired codes go to `/code/expired`, which links to `/code/resend`. |
| Phone (first time only) | `POST /interaction/{uid}/phone` | Identity API creates the account. |
| Consent prompt | `GET /interaction/{uid}` | **No page.** The app saves a grant for the requested scopes and resource and finishes the interaction. The provider and the runner are both Defra Forms, so there is nothing to ask the citizen. |

Details:

- **The gate:** every `/interaction` route runs `requireInteraction`, which loads the interaction and checks it against the `_interaction` cookie. An unknown or expired interaction shows a "timed out" page with status 410. The server refuses to start if any `/interaction` route skips the gate, so that a new route cannot forget the check.
- **Hashed ids:** identity UI keys one-time codes by `SHA-256(uid)`, and sends every provider id to identity API hashed, so that credentials stay out of logs and URLs.
- **CSRF:** the protocol routes (`/auth`, `/token`, `/token/revocation`, `/session/*`) skip the app's CSRF token check (crumb). `/token` and `/token/revocation` are server-to-server calls, and the provider checks its own `xsrf` value on sign-out.

## Provider endpoints

| Endpoint | Purpose |
|---|---|
| `/.well-known/openid-configuration` | Discovery. The runner reads it once after start-up. |
| `/auth`, `/auth/{uid}` | Authorization, and the resume after an interaction. |
| `/token` | Code exchange and refresh. |
| `/token/revocation` | Refresh token revocation. |
| `/jwks` | Public signing keys. |
| `/me` | Userinfo (not used, see [Scopes and claims](#scopes-and-claims)). |
| `/session/end`, `/session/end/confirm` | RP-initiated logout. |

## Cookies and sessions

| Where | Cookie / store | Holds |
|---|---|---|
| Identity UI | `_interaction`, `_session` (signed with `OIDC_COOKIE_KEYS`, `SameSite=Lax`, `Secure` when `OIDC_COOKIE_SECURE` is set). `Lax` rather than `Strict`, so that the cookies go with the top-level redirects from the runner, while other sites cannot send them on a cross-site `POST`. | Pointers to the interaction and the provider session. The data lives in identity API. |
| Identity UI | yar session in Redis (`SESSION_CACHE_TTL`) | Flash messages only. |
| Runner | yar session in Redis, server-side only (`maxCookieSize: 0`) | Sign-in transaction, identity (`iss`, `sub`, `email`), and the tokens. The browser holds only the session id. |

## Provider storage (identity API)

oidc-provider stores everything through an adapter. In identity UI, the adapter calls identity API:

| Method and path | Purpose |
|---|---|
| `PUT /oidc/{model}/{hash}` | Upsert |
| `GET /oidc/{model}/{hash}` | Find. **204** means "not found". |
| `GET /oidc/{model}/uid/{uid}` | Find by uid |
| `POST /oidc/{model}/{hash}/consume` | Consume |
| `DELETE /oidc/{model}/{hash}` | Destroy |
| `DELETE /oidc/grants/{grantId}` | Delete everything under a grant |

- **Models:** `session`, `interaction`, `grant`, `authorization_code`, `access_token`, `refresh_token`, `replay_detection`. Access tokens are JWTs, so the `access_token` collection stays empty.
- **Ids:** `{hash}` is `SHA-256(id)`, base64url.
- **Expiry:** each Mongo collection has a TTL index on `expireAt`.

Every call carries an **AWS STS web identity token**. The UI reuses the token until 1 minute before it expires. Identity API verifies it against the STS JWKS with RS256, checks `iss` and `aud`, and accepts one `sub`: the identity UI IAM role. So only identity UI can call identity API, with no shared secret between them.

## Resource server checks (forms-submission-api)

Strategy `citizen-access-token` (`@hapi/jwt`):

- **Keys:** from `CITIZEN_JWKS_URI`, the identity UI `/jwks`.
- **Checks:** the signature, `aud` = `CITIZEN_VERIFY_AUD` (the resource indicator the runner asks for), `iss` = `CITIZEN_VERIFY_ISS` (the identity UI public origin), `exp`, `nbf`, and a present `sub`.
- **Access:** saved-form records are read and changed only where `auth.sub` and `auth.issuer` match the token. Both are checked because a `sub` is unique only within its provider.

## Configuration reference

Values differ between environments, so this lists what each variable does, not its value.

**forms-identity-ui**

| Variable | Meaning |
|---|---|
| `OIDC_ISSUER` | The issuer and public origin. |
| `OIDC_JWKS` | Provider private signing keys (secret). |
| `OIDC_COOKIE_KEYS` | Keys that sign the provider cookies (secret). |
| `OIDC_COOKIE_SECURE` | Marks the provider cookies `Secure`. |
| `OIDC_RUNNER_JWKS` | The runner's public key, to verify its client assertions. |
| `OIDC_RUNNER_REDIRECT_URIS` | Allowed redirect URIs: the runner's `/auth/callback`. |
| `OIDC_RUNNER_POST_LOGOUT_REDIRECT_URIS` | Allowed sign-out return URIs: the runner's `/auth/signed-out`. |
| `OIDC_RESOURCE_SERVERS` | Allowed `resource` values. Must include the runner's `OIDC_SUBMISSION_API_RESOURCE`. |
| `OIDC_TTL_*` | Lifetimes; see [Tokens and lifetimes](#tokens-and-lifetimes). |
| `IDENTITY_API_URL`, `SERVICE_AUTH_AUDIENCE` | Identity API address, and the audience of the STS token. |

**forms-runner**

| Variable | Meaning |
|---|---|
| `USE_SIGN_IN_FEATURE` | Turns sign-in on. |
| `OIDC_ISSUER` | The identity UI origin; discovery starts here. |
| `OIDC_CLIENT_ID` | The client id. Must match the client registered in identity UI (`runner`). |
| `OIDC_REDIRECT_URI` | The runner's `/auth/callback`. Must be in `OIDC_RUNNER_REDIRECT_URIS`. |
| `OIDC_CLIENT_PRIVATE_JWK` | RSA private key that signs the client assertions (secret). Its public half is `OIDC_RUNNER_JWKS`. |
| `OIDC_SUBMISSION_API_RESOURCE` | The `resource` sent. Must equal the submission API's `CITIZEN_VERIFY_AUD`. |
| `OIDC_ACCESS_TOKEN_EXPIRY_GRACE_SECONDS` | Refresh this long before expiry. |
| `SESSION_TIMEOUT` | Rolling idle timeout, in ms. |

**forms-submission-api:** `CITIZEN_JWKS_URI` (the identity UI `/jwks`), `CITIZEN_VERIFY_AUD`, `CITIZEN_VERIFY_ISS` (must equal the identity UI `OIDC_ISSUER`).

**forms-identity-api:** `CDP_JWT_ISSUER`, `CDP_JWT_JWKS_URI`, `SERVICE`, `SERVICE_AUTH_ALLOWED_SUBJECT`, `OTP_TTL_SECONDS`, `OTP_MAX_ATTEMPTS`, `OTP_LOCKOUT_MAX_REQUESTS`, `OTP_LOCKOUT_WINDOW_SECONDS`, `OTP_LOCKOUT_DURATION_SECONDS`.

## Specifications

| Specification | Used for |
|---|---|
| OpenID Connect Core 1.0 | The flow, the ID token, `nonce`, `prompt`, `offline_access` |
| RFC 6749 | OAuth 2.0 authorization code and refresh grants |
| RFC 7636 | PKCE |
| RFC 7523 | JWT client assertions (`private_key_jwt`) |
| RFC 8707 | Resource indicators |
| RFC 7009 | Token revocation |
| OpenID Connect RP-Initiated Logout 1.0 | `/session/end` |
| RFC 9068 | JWT access token profile |
