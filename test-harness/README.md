# Local Development Dependencies With Mock Authentication

This directory contains instructions and configuration for spinning up all local development dependencies required by the Defra Forms application suite, including a mock authentication service.

## Prerequisites
- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/)


## Available Development Tools

The following development tools and infrastructure services are available when running `./run-harness.sh`:

| Name         | Description                                    | Development tool URL  | Used in production |
|--------------|------------------------------------------------|-----------------------|--------------------|
| localstack   | Local AWS cloud service emulator (used for S3) |                       | No                 |
| s3manager    | Local S3-compatible storage manager (minio)    | http://localhost:8082 | No                 |
| mongo        | MongoDB database for backends                  |                       | Yes                |
| mongo-express| Web-based MongoDB admin interface              | http://localhost:8081 | No                 |
| redis        | Redis cache/message broker for frontends       |                       | Yes                |
| cdp-uploader | File upload infrastructure                     |                       | Yes                |
| oidc         | Mock OIDC authentication server                |                       | No                 |
| forms-designer | Forms UI editor                              | http://localhost:3000 | Yes                |
| forms-manager | Forms file management                         |                       | Yes                |
| forms-runner | Forms runner                                   |                       | Yes                |
| forms-submission-api | Forms submission service               |                       | Yes                |
| forms-entitlement-api | Entitlement (authorization) service   |                       | Yes                |
| forms-audit-api | Audit service                               |                       | Yes                |

Create a `.env` file with the following typical contents (or copy from `example.env`):
```
# forms-designer
# forms-designer
AZURE_CLIENT_ID="local-test-client"
AZURE_CLIENT_SECRET="local-mock-secret"
OIDC_WELL_KNOWN_CONFIGURATION_URL="http://localhost:5556/.well-known/openid-configuration"
REDIS_USERNAME=default
REDIS_PASSWORD=my-password

FEATURE_FLAG_USE_ENTITLEMENT_API=false

# forms-manager
MANAGER_OIDC_JWKS_URI="http://host.docker.internal:5556/.well-known/openid-configuration/jwks"
MANAGER_OIDC_VERIFY_AUD="local-test-client"
MANAGER_OIDC_VERIFY_ISS="http://oidc:80"

# forms-runner
RUNNER_SESSION_COOKIE_PASSWORD="53409gjhfcdiklgjidfglkgjdflkelrku634"

# submission-api
SUBMISSION_OIDC_JWKS_URI="http://host.docker.internal:5556/.well-known/openid-configuration/jwks"
SUBMISSION_OIDC_VERIFY_AUD="local-test-client"
SUBMISSION_OIDC_VERIFY_ISS="http://oidc:80"

# entitlement-api
ENTITLEMENT_OIDC_JWKS_URI="http://host.docker.internal:5556/.well-known/openid-configuration/jwks"
ENTITLEMENT_OIDC_VERIFY_AUD="local-test-client"
ENTITLEMENT_OIDC_VERIFY_ISS="http://oidc:80"
```

To start all dependencies, run:

```sh
./run-harness.sh
```

This will spin up all the necessary containers for local development of the Defra Forms.
