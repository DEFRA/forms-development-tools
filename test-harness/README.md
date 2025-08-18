# Local Development Dependencies With Mock Authentication

This directory contains instructions and configuration for spinning up all local development dependencies required by the Defra Forms application suite, including a mock authentication service.

## Prerequisites
- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/)


## Available Development Tools

The following development tools and infrastructure services are available when running `docker compose up`:

| Name         | Description                                    | Development tool URL  | Used in production |
|--------------|------------------------------------------------|-----------------------|--------------------|
| localstack   | Local AWS cloud service emulator (used for S3) |                       | No                 |
| s3manager    | Local S3-compatible storage manager (minio)    | http://localhost:8082 | No                 |
| mongo        | MongoDB database for backends                  |                       | Yes                |
| mongo-express| Web-based MongoDB admin interface              | http://localhost:8081 | No                 |
| redis        | Redis cache/message broker for frontends       |                       | Yes                |
| cdp-uploader | File upload infrastructure                     |                       | Yes                |
| forms-designer | Forms UI editor                              | http://localhost:3000 | Yes                |
| forms-manager | Forms file management                         |                       | Yes                |
| forms-submission-api | Forms submission service               |                       | Yes                |
| forms-entitlement-api | Entitlement (authorization) service   |                       | Yes                |
| forms-audit-api | Audit service                               |                       | Yes                |

To start all dependencies, run:

```sh
./run-harness.sh
```

This will spin up all the necessary containers for local development of the Defra Forms.
