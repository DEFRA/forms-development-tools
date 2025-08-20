# Defra Forms Development Tools

This repository contains shared development tools and infrastructure for the Defra Forms application suite.

## Overview

Currently, the repository provides a Docker Compose setup to help developers spin up all the required dependencies for the following scenarios:

### 1. Local infrastructure for use with AAD/Entra auth
Spins up the infrastructure and services to allow forms-designer, forms-manager, forms-submission-api, forms-audit-api etc to be manually started, and for the authentication to use AAD/Entra.

It includes the CDP uploader infrastructure relevant for `forms-runner` and `forms-submission-api`.

```
cd local-development-dependencies
docker compose up
```

Instructions for running all local dependencies with Docker Compose can be found in [`local-development-dependencies/README.md`](./local-development-dependencies/README.md).

### 2. Local infrastructure for use with mock OIDC auth
Spins up the infrastructure and services to allow forms-designer, forms-manager, forms-submission-api, forms-audit-api etc to be manually started, and for the authentication to use a mock OIDC server.

It includes the CDP uploader infrastructure relevant for `forms-runner` and `forms-submission-api`.

```
cd local-development-mock-auth
docker compose up
```

Instructions for running all local dependencies with Docker Compose can be found in [`local-development-mock-auth/README.md`](./local-development-mock-auth/README.md).

### 3. Local infrastructure for all forms services including mock OIDC auth
Spins up the infrastructure and services including the following services:

- **forms-designer**
- **forms-manager**
- **forms-runner**
- **forms-submission-api**
- **forms-audit-api**
- **forms-entitlement-api**

```
cd test-harness
./run-harness.sh
```
Once started, to connect to designer, use:
```
http://localhost:3000
```

The login username/password of allowed users is defined in `/local-development-mock-auth/oidc-config/user.yml`.

Instructions for running all local dependencies can be found in [`test-harness/README.md`](./test-harness/README.md).

## Notes
- This repository is intended for development and local testing only.
- For more information about each service, refer to their respective repositories.