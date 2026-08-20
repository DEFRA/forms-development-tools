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

If using AAD/Entra authentication (as opposed to the mocked OIDC authentication), you will need to create a `.env` file with the following typical contents:
```
# forms-designer
AZURE_CLIENT_ID="<client-id>"
AZURE_CLIENT_SECRET="<client-secret>"
OIDC_WELL_KNOWN_CONFIGURATION_URL="https://login.microsoftonline.com/<tenant>>/v2.0/.well-known/openid-configuration"

REDIS_USERNAME=default
REDIS_PASSWORD=my-password

# forms-manager, submission-api, entitlement-api
OIDC_JWKS_URI="https://login.microsoftonline.com/<tenant>/discovery/v2.0/keys"
OIDC_VERIFY_AUD="<guid-audience>"
OIDC_VERIFY_ISS="https://login.microsoftonline.com/<tenant>/v2.0"

# forms-runner
RUNNER_SESSION_COOKIE_PASSWORD="53409gjhfcdiklgjidfglkgjdflkelrku634"
```

## aws-sts-stub

Stands in for the AWS STS `GetWebIdentityToken` API, which LocalStack does not
implement. forms-identity-ui mints a caller token from it and
forms-identity-api verifies that token against its key set, so both services
run the same authentication code here as in a deployed environment.

Runs on `http://localhost:4571`. Its issuer is the fixed constant
`https://local.tokens.sts.global.api.aws`, which must match
`CDP_JWT_ISSUER` on forms-identity-api exactly.

`run-harness.sh` pulls images with `--pull always`, so if the stub has not
yet been published to `ghcr.io`, build it locally under the tag the compose
file expects, from `test-harness`:

```bash
docker build -t ghcr.io/defra/aws-sts-stub:latest ../../aws-sts-stub
```

The same applies to `forms-identity-api` and `forms-identity-ui` while their
service-to-service auth code is still unmerged: a harness started from their
published images comes up looking healthy but runs with no
service-to-service auth at all, since those images predate the code that
enforces it. Nothing in the running system flags this, so rebuild both
images from the branch that has the auth code before trusting a harness run
to prove anything about it.

On an Apple Silicon host, build all three with `--platform linux/amd64`. Both
services pin `platform: linux/amd64` in the compose file, so an arm64 local
build is passed over and Compose falls back to the published amd64 image — the
same silent success as above, reached a different way.

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
     If AAD authentication is specified, you need to create a .env file with the necessary AAD config.

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
