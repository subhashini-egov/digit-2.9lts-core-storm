# DIGIT Core Services - Tiltfile
# Run with: tilt up

# Load extensions
load('ext://uibutton', 'cmd_button', 'location')
load('ext://restart_process', 'docker_build_with_restart')

# ==================== Configuration ====================
# Path to CCRS code (for live UI and PGR development)
# Clone CCRS repo as sibling: git clone https://github.com/egovernments/Citizen-Complaint-Resolution-System.git ../Citizen-Complaint-Resolution-System
CCRS_PATH = os.getenv('CCRS_PATH', '../Citizen-Complaint-Resolution-System')
FRONTEND_PATH = CCRS_PATH + '/frontend/micro-ui'
PGR_PATH = CCRS_PATH + '/backend/pgr-services'

# Detect CI mode - use full Docker builds without live reload
# GitHub Actions sets CI=true, or manually set TILT_CI=1 for CI-style builds
CI_MODE = os.getenv('CI', '') != '' or os.getenv('TILT_CI', '') != ''

# ==================== PGR Services ====================
if CI_MODE:
    # CI Mode: Use multi-stage Dockerfile (Maven inside Docker)
    # This doesn't require Maven installed on host
    # Dockerfile is in this repo, context is the CCRS backend
    docker_build(
        'pgr-services-dev',
        context=PGR_PATH,
        dockerfile='./docker/pgr-services/Dockerfile',
    )
else:
    # Local Dev Mode: Compile Java locally, then sync to container for fast hot reload
    # Requires: mvn installed locally
    # Check if Maven is available
    maven_check = local('which mvn || echo "not_found"', quiet=True)
    if 'not_found' in maven_check:
        fail('''
Maven not found! For local development with hot reload, install Maven:
  - macOS: brew install maven
  - Ubuntu: sudo apt install maven

Or run in CI mode without hot reload:
  TILT_CI=1 tilt up
''')

    local_resource(
        'pgr-compile',
        'cd ' + PGR_PATH + ' && mvn package -DskipTests -q && ' +
        'unzip -o target/pgr-services-*.jar -d target/extracted',
        deps=[PGR_PATH + '/src', PGR_PATH + '/pom.xml'],
        labels=['pgr'],
    )

    docker_build_with_restart(
        'pgr-services-dev',
        context=PGR_PATH + '/target/extracted',
        dockerfile_contents='''
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY . /app
ENTRYPOINT ["java", "-cp", ".:BOOT-INF/lib/*:BOOT-INF/classes", "org.egov.pgr.PgrApplication"]
''',
        entrypoint=['java', '-cp', '.:BOOT-INF/lib/*:BOOT-INF/classes', 'org.egov.pgr.PgrApplication'],
        live_update=[
            sync(PGR_PATH + '/target/extracted/BOOT-INF/lib', '/app/BOOT-INF/lib'),
            sync(PGR_PATH + '/target/extracted/BOOT-INF/classes', '/app/BOOT-INF/classes'),
            sync(PGR_PATH + '/target/extracted/META-INF', '/app/META-INF'),
        ],
    )

# ==================== DIGIT UI ====================
if CI_MODE:
    # CI Mode: Full Docker build
    docker_build(
        'digit-ui-dev',
        context=FRONTEND_PATH,
        dockerfile=FRONTEND_PATH + '/web/docker/Dockerfile',
        build_args={'WORK_DIR': '.'},
    )
else:
    # Local Dev Mode: Build with live sync for hot reload
    # Check if yarn is available for UI watching
    yarn_check = local('which yarn || echo "not_found"', quiet=True)
    if 'not_found' not in yarn_check:
        # UI watcher - recompiles on source changes
        # This runs webpack in watch mode for hot reload
        local_resource(
            'ui-watch',
            serve_cmd='cd ' + FRONTEND_PATH + '/web && yarn build:webpack --watch',
            deps=[FRONTEND_PATH + '/web/src'],
            labels=['frontend'],
            resource_deps=['digit-ui'],
            auto_init=False,  # Don't auto-start, trigger manually or enable via Tilt UI
        )

    docker_build(
        'digit-ui-dev',
        context=FRONTEND_PATH,
        dockerfile=FRONTEND_PATH + '/web/docker/Dockerfile',
        build_args={'WORK_DIR': '.'},
        live_update=[
            # Sync built JS/CSS (after local webpack build --watch)
            # Note: Don't sync public/ - it would overwrite the built index.html which has bundle script tags
            sync(FRONTEND_PATH + '/web/build/', '/var/web/digit-ui/'),
        ],
    )

# Load docker-compose configuration
docker_compose('./docker-compose.yml')

# ==================== Infrastructure ====================
dc_resource('postgres', labels=['infrastructure'])
dc_resource('redis', labels=['infrastructure'])
dc_resource('redpanda', labels=['infrastructure'])
dc_resource('elasticsearch', labels=['infrastructure'])

# ==================== Core Services ====================
dc_resource('egov-mdms-service', labels=['core-services'],
    links=[
        link('http://localhost:18094/mdms-v2/health', 'Health'),
    ])

dc_resource('egov-enc-service', labels=['core-services'],
    links=[
        link('http://localhost:11234/egov-enc-service/actuator/health', 'Health'),
    ])

dc_resource('egov-idgen', labels=['core-services'],
    links=[
        link('http://localhost:18088/egov-idgen/health', 'Health'),
    ])

dc_resource('egov-user', labels=['core-services'],
    links=[
        link('http://localhost:18107/user/health', 'Health'),
    ])

dc_resource('egov-workflow-v2', labels=['core-services'],
    links=[
        link('http://localhost:18109/egov-workflow-v2/health', 'Health'),
    ])

dc_resource('egov-localization', labels=['core-services'],
    links=[
        link('http://localhost:18096/localization/actuator/health', 'Health'),
    ])

dc_resource('egov-location', labels=['core-services'],
    links=[
        link('http://localhost:18084/egov-location/health', 'Health'),
    ])

dc_resource('boundary-service', labels=['core-services'],
    links=[
        link('http://localhost:18081/boundary-service/actuator/health', 'Health'),
    ])

dc_resource('egov-accesscontrol', labels=['core-services'],
    links=[
        link('http://localhost:18090/access/health', 'Health'),
    ])

dc_resource('egov-persister', labels=['core-services'],
    links=[
        link('http://localhost:18091/common-persist/actuator/health', 'Health'),
    ])

# ==================== API Gateway ====================
dc_resource('kong', labels=['gateway'],
    links=[
        link('http://localhost:18000', 'Proxy'),
        link('http://localhost:18001', 'Admin API'),
        link('http://localhost:18002', 'Manager GUI'),
    ])

# ==================== PGR Services ====================
dc_resource('pgr-services', labels=['pgr'],
    links=[
        link('http://localhost:18083/pgr-services/health', 'Health'),
    ])

dc_resource('digit-ui', labels=['frontend'],
    links=[
        link('http://localhost:18000/digit-ui/', 'UI via Kong'),
    ])

# ==================== Seed Jobs ====================
dc_resource('db-seed', labels=['seeds'], auto_init=True)
dc_resource('mdms-tenant-seed', labels=['seeds'], auto_init=True)
dc_resource('mdms-workflow-seed', labels=['seeds'], auto_init=True)
dc_resource('mdms-security-seed', labels=['seeds'], auto_init=True)
dc_resource('localization-seed', labels=['seeds'], auto_init=True)
dc_resource('user-schema-seed', labels=['seeds'], auto_init=True)

# ==================== Local Resources ====================

# Database reset - manually triggered only
local_resource(
    'nuke-db',
    cmd='docker compose down -v && docker compose up -d postgres redis redpanda elasticsearch',
    auto_init=False,
    labels=['maintenance'],
)

# ==================== Custom Buttons ====================

# Nuke Database button - removes all data and restarts infrastructure
cmd_button(
    name='nuke-db-btn',
    argv=['sh', '-c', 'docker compose down -v && docker compose up -d postgres redis redpanda elasticsearch'],
    location=location.NAV,
    icon_name='delete_forever',
    text='Nuke DB',
)

# Health Check button in the nav bar
cmd_button(
    name='health-check',
    argv=['./scripts/health-check.sh'],
    location=location.NAV,
    icon_name='favorite',
    text='Health Check',
)

# Smoke Tests button in the nav bar
cmd_button(
    name='smoke-tests',
    argv=['./scripts/smoke-tests.sh'],
    location=location.NAV,
    icon_name='science',
    text='Smoke Tests',
)

# Re-seed MDMS button (useful after restart)
cmd_button(
    name='reseed-mdms',
    argv=['sh', '-c', 'docker exec -i docker-postgres psql -U egov -d egov < ./db/seed.sql'],
    location=location.NAV,
    icon_name='refresh',
    text='Re-seed MDMS',
)

# Kong API Gateway test button
cmd_button(
    name='kong-test',
    argv=['./scripts/kong-test.sh', 'test'],
    location=location.NAV,
    icon_name='security',
    text='Kong Test',
)

# Test idgen button
cmd_button(
    name='idgen-test',
    argv=['sh', '-c', '''curl -s -X POST "http://localhost:18088/egov-idgen/id/_generate" \
      -H "Content-Type: application/json" \
      -d '{"RequestInfo":{"apiId":"digit","ver":"1.0"},"idRequests":[{"tenantId":"pg","idName":"pgr.servicerequestid"}]}' | jq .'''],
    location=location.NAV,
    icon_name='tag',
    text='Test idgen',
)

# Start Jupyter Lab button
cmd_button(
    name='jupyter-start',
    argv=['sh', '-c', 'docker compose --profile tools up -d jupyter && echo "Jupyter Lab: http://localhost:18888"'],
    location=location.NAV,
    icon_name='science',
    text='Start Jupyter',
)

# Start Gatus Health Dashboard button
cmd_button(
    name='gatus-start',
    argv=['sh', '-c', 'docker compose --profile tools up -d gatus && echo "Gatus Dashboard: http://localhost:18889"'],
    location=location.NAV,
    icon_name='monitor_heart',
    text='Start Gatus',
)

# ==================== Port Summary ====================
# Infrastructure:
#   - Postgres:      15432
#   - Redis:         16379
#   - Redpanda:      19092
#   - Elasticsearch: 19200
#
# API Gateway (Kong):
#   - Proxy:         18000 (external access point)
#   - Admin API:     18001
#   - Manager GUI:   18002
#   - Status:        18100
#
# Core Services:
#   - MDMS:          18094
#   - ENC:           11234
#   - IDGEN:         18088
#   - User:          18107
#   - Workflow:      18109
#   - Localization:  18096
#   - Location:      18084
#   - Boundary-v2:   18081
#   - AccessControl: 18090
#   - Persister:     18091
#
# PGR & Frontend:
#   - PGR-Services:  18083
#   - DIGIT-UI:      18080
