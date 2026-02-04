# DIGIT Core Services - Startup Sequence

This document describes the startup sequence and dependencies for DIGIT core services.

## Dependency Graph

```
                    ┌─────────────────────────────────────────────────┐
                    │            INFRASTRUCTURE LAYER                  │
                    │  ┌─────────┐  ┌─────────┐  ┌─────────────────┐  │
                    │  │Postgres │  │  Redis  │  │    Redpanda     │  │
                    │  └────┬────┘  └────┬────┘  └────────┬────────┘  │
                    │       │            │                │           │
                    └───────┼────────────┼────────────────┼───────────┘
                            │            │                │
                            ▼            ▼                ▼
                    ┌─────────────────────────────────────────────────┐
                    │              CORE SERVICES (Tier 1)              │
                    │                                                  │
                    │  ┌────────────────────┐  ┌───────────────────┐  │
                    │  │  egov-mdms-service │  │  egov-localization│  │
                    │  │  (Flyway creates   │  │  (Independent)    │  │
                    │  │   MDMS tables)     │  │                   │  │
                    │  └─────────┬──────────┘  └───────────────────┘  │
                    │            │                                     │
                    └────────────┼─────────────────────────────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────────────────────────────┐
                    │                 SEED JOBS (Tier 2)               │
                    │                                                  │
                    │  ┌──────────────────┐                           │
                    │  │ mdms-tenant-seed │ ← Waits for MDMS tables   │
                    │  │ (Seeds: tenant)  │                           │
                    │  └────────┬─────────┘                           │
                    │           │                                      │
                    │           ▼                                      │
                    │  ┌───────────────────────┐                      │
                    │  │  mdms-workflow-seed   │                      │
                    │  │  (Seeds: Workflow)    │                      │
                    │  └───────────────────────┘                      │
                    │                                                  │
                    │  ┌───────────────────────┐                      │
                    │  │  localization-seed    │ ← After localization │
                    │  └───────────────────────┘                      │
                    └─────────────────────────────────────────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────────────────────────────┐
                    │           DEPENDENT SERVICES (Tier 3)            │
                    │                                                  │
                    │  ┌───────────────────┐  ┌───────────────────┐   │
                    │  │  egov-enc-service │  │    egov-idgen     │   │
                    │  │  (Needs: tenant)  │  │  (Needs: MDMS)    │   │
                    │  └─────────┬─────────┘  └───────────────────┘   │
                    │            │                                     │
                    │            ▼                                     │
                    │  ┌───────────────────┐  ┌───────────────────┐   │
                    │  │    egov-user      │  │ egov-workflow-v2  │   │
                    │  │  (Needs: enc,     │  │  (Needs: Workflow │   │
                    │  │   tenant-seed)    │  │   MDMS seed)      │   │
                    │  └───────────────────┘  └───────────────────┘   │
                    │                                                  │
                    │  ┌───────────────────┐  ┌───────────────────┐   │
                    │  │  egov-location    │  │ egov-accesscontrol│   │
                    │  │  boundary-service │  │   egov-persister  │   │
                    │  └───────────────────┘  └───────────────────┘   │
                    └─────────────────────────────────────────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────────────────────────────┐
                    │            FINAL SEED & APPS (Tier 4)            │
                    │                                                  │
                    │  ┌─────────────────────────────────────────┐    │
                    │  │                db-seed                   │    │
                    │  │  (Final seed after all services ready)   │    │
                    │  └─────────────────────────────────────────┘    │
                    │                                                  │
                    │  ┌───────────────────┐  ┌───────────────────┐   │
                    │  │   pgr-services    │  │     digit-ui      │   │
                    │  │  (Full stack)     │  │   (Frontend)      │   │
                    │  └───────────────────┘  └───────────────────┘   │
                    │                                                  │
                    │  ┌───────────────────────────────────────────┐  │
                    │  │                   Kong                     │  │
                    │  │              (API Gateway)                 │  │
                    │  └───────────────────────────────────────────┘  │
                    └─────────────────────────────────────────────────┘
```

## Startup Order (Detailed)

### Phase 1: Infrastructure
| Service | Port | Health Check | Notes |
|---------|------|--------------|-------|
| postgres | 15432 | `pg_isready` | Creates `egov` database |
| redis | 16379 | `redis-cli ping` | Session/cache store |
| redpanda | 19092 | `rpk cluster health` | Kafka-compatible broker |
| elasticsearch | 19200 | `/_cluster/health` | Search/indexing |

### Phase 2: Core Services (No MDMS dependencies)
| Service | Port | Depends On | Flyway Table |
|---------|------|------------|--------------|
| egov-mdms-service | 18094 | postgres, redpanda | `mdms_schema_version` |
| egov-localization | 18096 | postgres, redpanda, redis | `localization_schema_version` |
| egov-accesscontrol | 18090 | postgres, redpanda | `accesscontrol_schema_version` |
| egov-persister | 18091 | postgres, redpanda | N/A (config-driven) |

### Phase 3: MDMS Seeds
| Seed | Depends On | Seeds |
|------|------------|-------|
| mdms-tenant-seed | MDMS healthy + tables exist | `tenant.tenants` |
| mdms-workflow-seed | mdms-tenant-seed completed | `Workflow.BusinessServiceMasterConfig` |
| localization-seed | egov-localization healthy | localization messages |

### Phase 4: Services needing MDMS data
| Service | Port | MDMS Requirements | Other Dependencies |
|---------|------|-------------------|-------------------|
| egov-enc-service | 11234 | `tenant.tenants` | mdms-tenant-seed |
| egov-idgen | 18088 | MDMS host config | MDMS healthy |
| egov-user | 18107 | `Security.*`, tenant | enc-service, mdms-tenant-seed |
| egov-workflow-v2 | 18109 | `Workflow.*` | mdms-workflow-seed |
| egov-location | 18084 | - | postgres, redpanda |
| boundary-service | 18081 | - | MDMS healthy |

### Phase 5: Application Services
| Service | Port | Depends On |
|---------|------|------------|
| pgr-services | 18083 | idgen, user, workflow, localization |
| digit-ui | 18080 | None (static frontend) |
| kong | 18000 | MDMS, user |

### Phase 6: Final Seeds
| Seed | Depends On | Seeds |
|------|------------|-------|
| db-seed | All core services healthy | idgen formats, roles, etc. |

## MDMS Data Dependencies

### Required MDMS Schemas
```
tenant.tenants          → Used by: enc-service, user
Workflow.BusinessServiceMasterConfig → Used by: workflow-v2
Security.EncryptionPolicy           → Used by: user (encryption lib)
common-masters.IdFormat             → Used by: idgen
```

### Critical Timing Issue
The MDMS service reports "healthy" as soon as its HTTP endpoint responds, but Flyway migrations may still be running. Seeds must wait for tables to exist:

```bash
# Wait pattern used in seed entrypoints
until psql ... -c 'SELECT 1 FROM eg_mdms_schema_definition LIMIT 1'; do
  sleep 2;
done;
```

## Ports Summary

| Range | Purpose |
|-------|---------|
| 15432 | Postgres |
| 16379 | Redis |
| 19092 | Redpanda (Kafka) |
| 19200 | Elasticsearch |
| 18000-18002 | Kong Gateway |
| 18080 | DIGIT UI |
| 18081-18109 | Core Services |
| 11234 | Encryption Service |

## Troubleshooting

### Service won't start - MDMS errors
Check if MDMS seeds completed:
```bash
docker exec docker-postgres psql -U egov -d egov -c "SELECT schemacode FROM eg_mdms_data;"
```

### Flyway migration conflicts
Each service uses unique `SPRING_FLYWAY_TABLE`:
- mdms_schema_version
- idgen_schema_version
- workflow_schema_version
- etc.

### Check service logs
```bash
docker logs <service-name> 2>&1 | tail -50
```

### Restart a specific service
```bash
docker compose restart <service-name>
```

### idgen "No Format is available" error
Ensure MDMS IdFormat is seeded:
```bash
docker exec docker-postgres psql -U egov -d egov -c "SELECT data FROM eg_mdms_data WHERE schemacode = 'common-masters.IdFormat';"
```

### idgen "Error retrieving seq number" / sequence not found
1. Check if required sequence exists:
```bash
docker exec docker-postgres psql -U egov -d egov -c "\ds seq_eg_pgr_id"
```

2. Create missing sequence:
```bash
docker exec docker-postgres psql -U egov -d egov -c "CREATE SEQUENCE IF NOT EXISTS seq_eg_pgr_id START 1;"
```

3. Enable auto-creation via environment:
```yaml
AUTOCREATE_NEW_SEQ: 'true'
```

### idgen "Missing property city" error
Tenant data must include `city.code` for idgen. Update tenant records:
```sql
UPDATE eg_mdms_data
SET data = data || '{"city":{"code":"PB","name":"Punjab"}}'::jsonb
WHERE schemacode = 'tenant.tenants' AND (data->>'code') = 'pg' AND (data->'city') IS NULL;
```

### OpenTelemetry JDBC driver issues
If you see "Driver io.opentelemetry.instrumentation.jdbc.OpenTelemetryDriver claims to not accept jdbcUrl", add:
```yaml
SPRING_DATASOURCE_DRIVER_CLASS_NAME: org.postgresql.Driver
```
