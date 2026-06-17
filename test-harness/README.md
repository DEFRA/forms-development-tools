# Test Harness

Spins up the full Defra Forms stack — all forms microservices (designer, manager, runner, submission, entitlement, audit) plus their runtime dependencies — via a single `run-harness.sh` script. Use this if you want everything running without starting services individually.

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
| oidc                  | Mock OIDC authentication server                |                       | No                 |
| forms-designer        | Forms UI editor                                | http://localhost:3000 | Yes                |
| forms-manager         | Forms file management                          |                       | Yes                |
| forms-runner          | Forms runner                                   |                       | Yes                |
| forms-submission-api  | Forms submission service                       |                       | Yes                |
| forms-entitlement-api | Entitlement (authorization) service            |                       | Yes                |
| forms-audit-api       | Audit service                                  |                       | Yes                |

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
sudo sh -c 'echo "127.0.0.1 uploader.127.0.0.1.sslip.io cdp.127.0.0.1.sslip.io" >> /etc/hosts'
```
