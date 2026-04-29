# My Animalzz

An enterprise grade Spring Boot 4 service used as the EKS + managed-Postgres target in the "Great European Cloud Escape" Substack series.

It exposes a handful of read-only REST endpoints over a simple `Species` / `Animal` domain, backed by JPA and seeded with sample data on first startup.

## Stack

- Java 25, Spring Boot 4
- Lombok for boilerplate
- springdoc-openapi for OpenAPI 3 / Swagger UI
- Spring Cloud AWS (S3) for object storage
- LocalStack 4 for a local S3 (and friends) emulator

## Running locally

From `ep4-eks-db/app/`:

```shell
docker compose up -d --build --remove-orphans
```

This boots three containers:

- **postgres** — PostgreSQL 18 for the JPA layer; the app connects via `SPRING_DATASOURCE_*` env vars and lets Hibernate create the schema.
- **localstack** — LocalStack 4 emulating S3 on `http://localhost:4566`. An init script (`localstack-init/01-create-bucket.sh`) provisions the `animal-images` bucket as the container becomes ready — the Java code never creates the bucket.
- **app** — this service, on `http://localhost:8080`, wired to both.

On first start, `DataInitializer` seeds three species (Red Panda, African Elephant, Gray Wolf) and four animals.

## Endpoints

All endpoints are rooted at `/api`.

| Method | Path                        | Description                                                                     |
| ------ | --------------------------- | ------------------------------------------------------------------------------- |
| GET    | `/api/species`              | List all species                                                                |
| GET    | `/api/animals`              | List all animals                                                                |
| GET    | `/api/species/{id}/animals` | List animals belonging to a species                                             |
| POST   | `/api/images/random`        | Download a random image from the internet and store it in S3 under a unique key |

The `POST /api/images/random` endpoint fetches a JPEG from `https://picsum.photos/400/300` (override with `APP_RANDOM_IMAGE_URL`) and uploads it to S3 via Spring Cloud AWS' `S3Template`. The object key is `random-image-<epoch-millis>.jpg`, and the response is `{"key": "random-image-..."}`.

Inspect the uploaded objects against LocalStack with:

```shell
aws --endpoint-url=http://localhost:4566 s3 ls s3://animal-images
```

Actuator endpoints are available under `/actuator` (health, info, etc.).

## Swagger UI

With the app running on port 8080:

- Swagger UI: `http://localhost:8080/swagger-ui/index.html`
- OpenAPI JSON: `http://localhost:8080/v3/api-docs`
