# DIGIT Core Services - Docker Compose

Run a minimal DIGIT core stack locally with Postgres, Redis, Kafka, Elasticsearch, and the core platform services. This repo includes seed data for the tenant "pg" (short for playground) and a Postman collection for quick validation.

## What is Included

Infrastructure:
- Postgres 16
- Redis 7
- Kafka (Bitnami, KRaft)
- Elasticsearch 8

Core services:
- MDMS v2
- ENC service
- IDGEN
- User service
- Workflow v2
- Localization
- Location
- Access Control
- Persister

Seed jobs (one-shot):
- Tenant MDMS seed
- Workflow MDMS seed
- Localization seed
- Core DB seed

## Service Ports

Ports are mapped from the docker-compose file.

| Service | Container | Port(s) |
| --- | --- | --- |
| Postgres | `docker-postgres` | `5432` |
| Redis | `sdcrs-redis` | `6379` |
| Kafka | `sdcrs-kafka` | `9092` |
| Elasticsearch | `sdcrs-elasticsearch` | `9200` |
| ENC service | `egov-enc-service` | `1234` |
| MDMS v2 | `egov-mdms-service` | `8094` |
| IDGEN | `egov-idgen` | `8088` |
| User service | `egov-user` | `8107` |
| Workflow v2 | `egov-workflow-v2` | `8109` |
| Localization | `egov-localization` | `8096` |
| Location | `egov-location` | `8084` |
| Access Control | `egov-accesscontrol` | `8090` |
| Persister | `egov-persister` | `8091` |

## Prerequisites

- Docker Desktop (or Docker Engine)
- Docker Compose v2

## Quick Start

Start the stack:
```bash
docker compose up -d
```

Watch startup logs:
```bash
docker compose logs -f
```

Stop everything:
```bash
docker compose down
```

## Validation

Health checks (examples):
```bash
curl -sS http://localhost:8094/mdms-v2/health
curl -sS http://localhost:8107/user/health
curl -sS http://localhost:8096/localization/actuator/health
```

Localization search (v1, seeded data):
```bash
curl -sS -X POST "http://localhost:8096/localization/messages/v1/_search?locale=en_IN&module=rainmaker-workbench&tenantId=pg" \
  -H "Content-Type: application/json" \
  -d '{"RequestInfo":{"apiId":"Rainmaker","ver":".01","ts":""}}'
```

If localization returns empty, clear Redis cache:
```bash
curl -sS -X POST "http://localhost:8096/localization/messages/cache-bust"
```

### Postman collection:

Import the Postman collection and run all to know the status of containers:

- `postman/digit-core-validation.postman_collection.json`

## Postgres Access

Connect to the DB container:
```bash
docker exec -it docker-postgres psql -U egov -d egov
```

## Notes

- MDMS v2 (master data stored in DB) is used in the stack.
- Seed containers run once and exit; check status with `docker compose ps -a`.
- The localization seed targets the `message` table used by the current localization service schema.

## Known Issues

- Localization contains sample data for a trade license module
- Location (boundary-v2) is failing.
- Gateway, Indexer & other services are not part of the docker compose for now.

## Enhancements
- Set up boundary v2 and add seed data
- Add PGR service and UI 
- Add indexer to test out the data pipeline to ES
>>>>>>> 2cc64fa (Initial cut of docker compose)
