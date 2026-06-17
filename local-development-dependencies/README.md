# Local Development Dependencies

Spins up the runtime infrastructure required by the Defra Forms microservices — MongoDB, Redis, S3 (LocalStack), and CDP uploader — via Docker Compose. No forms microservices are started here.

If you want the full stack including the forms microservices, see the [test harness](../test-harness/README.md) instead.

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

To start all dependencies using Docker Compose (if requiring AAD authentication), run:

```sh
docker compose up
```

To start all dependencies using Docker Compose (if requiring mock OIDC authentication), run:

```sh
docker compose --profile oidc up
```

This will spin up all the necessary containers for local development of the Defra Forms.

To stop and remove the containers, run:

```sh
docker compose down
```