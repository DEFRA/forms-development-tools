# Defra Forms Development Tools

This repository contains shared development tools and infrastructure for the Defra Forms application suite.

## Overview

Currently, the repository provides a Docker Compose setup to help developers spin up all the required dependencies for the following scenarios:

### 1. Local infrastructure for use with AAD/Entra authentication
Spins up the infrastructure and services to allow forms-designer, forms-manager, forms-submission-api, forms-audit-api etc to be manually started, and for the authentication to use AAD/Entra.

It includes the CDP uploader infrastructure relevant for `forms-runner` and `forms-submission-api`.

Ensure you have the necessary `secrets.env` values which should be pulled through into both auth types.

```
NOTIFY_API_KEY=<notify api key>
```

Ensure you have the necessary `.env` values configured for AAD. See [`test-harness/README.md`](./test-harness/README.md).

```
cd test-harness
./run-harness.sh auth=AAD
```

Instructions for running all local dependencies with Docker Compose can be found in [`local-development-dependencies/README.md`](./local-development-dependencies/README.md).

### 2. Local infrastructure for use with mock OIDC authentication
Spins up the infrastructure and services to allow forms-designer, forms-manager, forms-submission-api, forms-audit-api etc to be manually started, and for the authentication to use a mock OIDC server.

It includes the CDP uploader infrastructure relevant for `forms-runner` and `forms-submission-api`.

```
cd test-harness
./run-harness.sh
```

For mock OIDC authentication, the login username/password of allowed users is defined in `/local-development-dependencies/oidc-config/user.yml`.

Instructions for running all local dependencies with Docker Compose can be found in [`local-development-dependencies/README.md`](./local-development-dependencies/README.md).

### 3. As for 1 or 2 above, but restrict the Forms services being started
Spins up the base infrastructure and ONLY the specified forms services :

```
cd test-harness
./run-harness.sh include=forms-manager,forms-entitlement-api
```

Spins up the base infrastructure and ALL the forms services EXCEPT those specified:

```
cd test-harness
./run-harness.sh exclude=forms-designer,forms-audit-api
```

The forms services include:
- **forms-designer**
- **forms-manager**
- **forms-runner**
- **forms-submission-api**
- **forms-audit-api**
- **forms-entitlement-api**

Once started, to connect to designer, use:
```
http://localhost:3000
```

For mock OIDC authentication, the login username/password of allowed users is defined in `/local-development-dependencies/oidc-config/user.yml`.

Instructions for running all local dependencies can be found in [`test-harness/README.md`](./test-harness/README.md).

## Notes
- This repository is intended for development and local testing only.
- For more information about each service, refer to their respective repositories.
