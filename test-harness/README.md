# Test Harness

Spins up the full Defra Forms stack — all forms microservices (designer, manager, runner, submission, entitlement, audit, identity) plus their runtime dependencies — via a single `run-harness.sh` script. Use this if you want everything running without starting services individually.

If you only need the backing infrastructure (MongoDB, Redis, S3, CDP uploader) and plan to run the microservices yourself, see [`local-development-dependencies`](../local-development-dependencies/README.md) instead.

## Prerequisites
- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/)
- [jq](https://jqlang.org/) 


## Available Development Tools

The following development tools and infrastructure services are available when running `./run-harness.sh`:

| Name                  | Description                                    | Development tool URL  | Used in production |
| --------------------- | ---------------------------------------------- | --------------------- | ------------------ |
| localstack            | Local AWS cloud service emulator (used for S3) |                       | No                 |
| s3manager             | Local S3-compatible storage manager (minio)    | http://localhost:8082 | No                 |
| mongo                 | MongoDB database for backends                  |                       | Yes                |
| mongo-express         | Web-based MongoDB admin interface              | http://localhost:8081 | No                 |
| redis                 | Redis cache/message broker for frontends       |                       | Yes                |
| cdp-uploader          | File upload infrastructure                     |                       | Yes                |
| aws-sts-stub          | AWS STS token stub for service-to-service auth | http://localhost:4571 | No                 |
| oidc                  | Mock OIDC authentication server                |                       | No                 |
| forms-designer        | Forms UI editor                                | http://localhost:3000 | Yes                |
| forms-manager         | Forms file management                          |                       | Yes                |
| forms-runner          | Forms runner                                   |                       | Yes                |
| forms-submission-api  | Forms submission service                       |                       | Yes                |
| forms-entitlement-api | Entitlement (authorization) service            |                       | Yes                |
| forms-audit-api       | Audit service                                  |                       | Yes                |
| forms-identity-api    | Citizen accounts and one-time security codes   |                       | Yes                |
| forms-identity-ui     | Citizen sign in, and the OIDC provider forms-runner authenticates against | http://identity.127.0.0.1.sslip.io:3011 | Yes |

## Settings

The harness reads its settings from up to three files in this directory. Docker Compose reads them in the order below, and a value in a later file overrides the same setting in an earlier file.

| Order | File          | Checked in | Required | Purpose                                                                                      |
| ----- | ------------- | ---------- | -------- | -------------------------------------------------------------------------------------------- |
| 1     | `base.env`    | Yes        | Yes      | Non-sensitive defaults. Sensitive settings are listed with an empty value.                   |
| 2     | `.env`        | No         | No       | Your local overrides and all sensitive settings, such as API keys.                           |
| 3     | `secrets.env` | No         | No       | Legacy location for sensitive settings. No longer needed and may be removed in future.       |

Only `base.env` is required, so the harness starts on a fresh clone without any extra files.

`run-harness.sh` passes these files directly to Docker Compose and prints the files it used. There is no generated `tmp.env` file any more. If you have one left over from an earlier version, it is not read and can be deleted.

A variable exported in the shell overrides all three files. For example, `FORMS_RUNNER_TAG=1.2.3 ./run-harness.sh` runs a specific forms-runner image for that run only.

### Sensitive settings

Put every sensitive setting in `.env`. The file is ignored by Git and must never be checked in. `base.env` lists each sensitive setting with an empty value and a comment marked `SENSITIVE`, so you can see what is available. Create `.env` with the ones you need:

```
NOTIFY_API_KEY=<GOV.UK Notify API key>
ORDNANCE_SURVEY_API_KEY=<Ordnance Survey API key>
ORDNANCE_SURVEY_API_SECRET=<Ordnance Survey API secret>
```

The harness still starts without these values, but email cannot be sent and the Ordnance Survey map and location features do not work.

`secrets.env` is no longer required. If you already have one, move its contents into `.env` and delete it. While `secrets.env` exists, its values override the same settings in `.env`.

### Changing other settings

- To change a setting for yourself only, add it to `.env`. Do not edit `base.env` for a local change.
- To change a default for everyone, edit `base.env` and commit it. Keep the comments in that file up to date.
- `docker-compose.yml` has further optional settings with built-in defaults, such as the image tags (`FORMS_DESIGNER_TAG`), feature flags (`FEATURE_FLAG_ALLOW_PAYMENTS`) and the SharePoint settings. These are written as `${NAME:-default}` in that file and can be set in `.env` in the same way.

The Docker network settings in `application.properties` are separate. The script exports them as shell variables, so they cannot be overridden from the env files.

### Using Entra authentication

By default the harness uses the mock OIDC server, and `base.env` holds the settings that point the services at it. To use AAD/Entra authentication instead, override these six settings in `.env`:

```
# forms-designer, forms-entitlement-api
AZURE_CLIENT_ID=<client-id>
AZURE_CLIENT_SECRET=<client-secret>

# forms-designer
OIDC_WELL_KNOWN_CONFIGURATION_URL=https://login.microsoftonline.com/<tenant>/v2.0/.well-known/openid-configuration

# back-end services
OIDC_JWKS_URI=https://login.microsoftonline.com/<tenant>/discovery/v2.0/keys
OIDC_VERIFY_AUD=<guid-audience>
OIDC_VERIFY_ISS=https://login.microsoftonline.com/<tenant>/v2.0
```

Then start the harness with `auth=Entra`, which leaves out the mock OIDC server.

These overrides apply whichever `auth` mode is selected. To go back to mock authentication, remove them from `.env` or comment them out so that the `base.env` defaults apply again.

## aws-sts-stub

Stands in for the AWS STS `GetWebIdentityToken` API, which LocalStack does not
implement. forms-identity-ui mints a caller token from it and
forms-identity-api verifies that token against its key set, so both services
run the same authentication code here as in a deployed environment.

Runs on `http://localhost:4571`. Its issuer is the fixed constant
`https://local.tokens.sts.global.api.aws`, which must match
`CDP_JWT_ISSUER` on forms-identity-api exactly. The image is pulled from
Docker Hub as
[`defradigital/aws-sts-stub`](https://hub.docker.com/r/defradigital/aws-sts-stub).

### Running unpublished service code

While the service-to-service auth code in `forms-identity-api` and
`forms-identity-ui` is still unmerged, a harness started from their published
images comes up looking healthy but runs with no service-to-service auth at
all, since those images predate the code that enforces it. Nothing in the
running system flags this, so run both services from a local build of the
branch that has the auth code before trusting a harness run to prove
anything about it.

`run-harness.sh` refreshes every image from its registry on each run, so a
local build under the published `latest` tag is overwritten by the pull.
Build under a tag that does not exist on Docker Hub instead — the pull of
that tag fails, the script carries on, and the service starts from the
local image:

```bash
docker build --platform linux/amd64 -t defradigital/forms-identity-api:local ../../forms-identity-api
docker build --platform linux/amd64 -t defradigital/forms-identity-ui:local ../../forms-identity-ui

FORMS_IDENTITY_API_TAG=local FORMS_IDENTITY_UI_TAG=local ./run-harness.sh
```

`--platform linux/amd64` matters on an Apple Silicon host: both services pin
`platform: linux/amd64` in the compose file, so an arm64 local build is
passed over and Compose falls back to the published amd64 image — the same
silent success as above, reached a different way.

## Citizen sign in

`forms-identity-ui` is an OIDC provider and `forms-runner` is a client.
The runner proves itself by signing a short-lived assertion (`private_key_jwt`)
rather than with a shared secret, so the two hold halves of one keypair: the
private half sits on forms-runner and the public half on forms-identity-ui.

Both halves, the provider's own signing key and the cookie secrets are test
values written into `docker-compose.yml`, so sign in works on a fresh clone with
nothing to generate. They are local-only and must never reach a deployment.

Sign in is on by default. To run forms-runner without it, set
`USE_SIGN_IN_FEATURE=false` in `.env` and optionally omit the forms-identity*
services when running this harness.

### Replacing the keys

Check out the `forms-identity-ui` repo locally and execute:

#### Main signing keys

```sh
node scripts/generate-jwks.mjs            # OIDC_JWKS
```

This script outptus the full key pair, which can be copied into `OIDC_JWKS`.

#### forms-runner's client key pair

The runner's keypair comes a second script, which prints both halves.

```sh
node scripts/generate-client-keypair.mjs > runner-keypair.txt

# public half -> OIDC_RUNNER_JWKS on forms-identity-ui, a JWKS set
grep '^OIDC_RUNNER_JWKS=' runner-keypair.txt

# private half -> OIDC_CLIENT_PRIVATE_JWK on forms-runner. It is printed as the
# JWKS set EXAMPLE_RP_PRIVATE_JWKS, but forms-runner only needs a single JWK, so
# extract the first item:
sed -n 's/^EXAMPLE_RP_PRIVATE_JWKS=//p' runner-keypair.txt | jq -c '.keys[0]'
```

## Starting the harness

To start all dependencies, run:

```sh
./run-harness.sh
```

Some command-line parameters are allowed:

* include=SERVICES
  * start the services specified, where SERVICES can be a CSV list of service names that are the forms-xxxx services (such as forms-designer, forms-manager etc)

* exclude=SERVICES
  * start all except the services specified, where SERVICES can be a CSV list of service names that are the forms-xxxx services (such as forms-designer, forms-manager etc)

* auth=MODE
  * set the authentication, where MODE can be either AAD or Entra (to denote AAD authentication), or either mock or OIDC (to denote mocked OIDC authentication). Default is mocked OIDC.
     If AAD authentication is specified, the mock OIDC server is not started and you need to add the AAD config to your `.env` file (see [Using Entra authentication](#using-entra-authentication)).

Examples:
  To start only forms-manager and forms-entitlement-api with AAD auth:

  ```
  ./run-harness.sh include=forms-manager,forms-entitlement-api auth=Entra
  ```

  To start everything except forms-designer with mocked OIDC auth:

  ```
  ./run-harness.sh exclude=forms-designer auth=mock
  ```

This will spin up all the necessary containers for local development of the Defra Forms.

## Issues

If you encounter an issue with uploading files using JavaScript, it will likely be because `uploader.127.0.0.1.sslip.io` is not resolving to `127.0.0.1` on your machine. This may be caused by your home router and how it's handling DNS. A way to resolve this is to add an entry to your hosts file. 

On Mac, you can do this by running this command:

```bash
sudo sh -c 'echo "127.0.0.1 uploader.127.0.0.1.sslip.io cdp.127.0.0.1.sslip.io identity.127.0.0.1.sslip.io" >> /etc/hosts'
```
