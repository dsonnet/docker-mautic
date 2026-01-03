# Portainer Deployment Troubleshooting

## Issue: mautic_web container exited (1)

This error occurs when deploying the Mautic stack in Portainer after separating the database.

### Root Cause

The issue is likely one of the following:
1. Percona database stack not running yet
2. Database connection parameters not correctly set
3. Network connectivity issue
4. `external_links` not working in Portainer

### Solution Steps

#### Step 1: Ensure Percona Stack is Running First

1. **Check Percona Stack Status**
   - Portainer → Stacks → percona-db
   - Status should be **Active** (green)
   - Container `percona-db` should be **running**

2. **If Percona Not Running:**
   - Deploy Percona stack first
   - Wait for it to be fully started (check logs)
   - Then deploy Mautic stack

#### Step 2: Check .mautic_env Configuration

The `.mautic_env` file MUST contain these values:

```bash
MAUTIC_DB_HOST=percona-db
MAUTIC_DB_PORT=3306
MAUTIC_DB_DATABASE=mautic
MAUTIC_DB_USER=mautic
MAUTIC_DB_PASSWORD=your_password_here
```

**Important:** The `MAUTIC_DB_HOST` must be `percona-db` (the container name in the Percona stack).

#### Step 3: Verify docker-compose.yml Has NO external_links

If your `docker-compose.yml` still has `external_links`, remove them. They don't work reliably in Portainer.

**Bad (remove this):**
```yaml
mautic_web:
  # ...
  external_links:
    - percona-db:mysql  # ← REMOVE THIS
```

**Good (use this):**
```yaml
mautic_web:
  image: mautic/mautic:6.0.7-apache
  volumes: *mautic-volumes
  environment:
    - DOCKER_MAUTIC_LOAD_TEST_DATA=${DOCKER_MAUTIC_LOAD_TEST_DATA}
    - DOCKER_MAUTIC_RUN_MIGRATIONS=${DOCKER_MAUTIC_RUN_MIGRATIONS}
  env_file:
    - .mautic_env
  healthcheck:
    test: curl http://localhost
    start_period: 5s
    interval: 5s
    timeout: 5s
    retries: 100
  networks:
    - default
    - web
    - mautic-db-network  # ← This is how containers find percona-db
  labels:
    # ... traefik labels
```

#### Step 4: Verify Network Configuration

1. **Check Network Exists**
   - Portainer → Networks
   - Look for `mautic-db-network`
   - Should show both stacks connected

2. **Network Configuration in Percona Stack:**
```yaml
networks:
  mautic-db-network:
    name: mautic-db-network
    driver: bridge
```

3. **Network Configuration in Mautic Stack:**
```yaml
networks:
  # ... other networks
  mautic-db-network:
    external: true
    name: mautic-db-network
```

#### Step 5: Check Container Logs for Actual Error

1. **View Mautic Web Logs**
   - Portainer → Containers
   - Find `mautic_web` container (even if stopped)
   - Click **Logs**
   - Look for the actual error message

2. **Common Errors and Solutions:**

   **Error: "Connection refused" or "Can't connect to MySQL server"**
   - Solution: Percona stack not running
   - Fix: Start Percona stack first

   **Error: "Access denied for user"**
   - Solution: Wrong password in `.mautic_env`
   - Fix: Ensure password matches Percona stack

   **Error: "Unknown MySQL server host 'mysql'"**
   - Solution: Still using old host name
   - Fix: Change `MAUTIC_DB_HOST` to `percona-db`

   **Error: "php_network_getaddresses: getaddrinfo failed"**
   - Solution: Network issue
   - Fix: Ensure both stacks on `mautic-db-network`

#### Step 6: Updated docker-compose.yml for Portainer

Use this corrected version:

```yaml
x-mautic-volumes:
  &mautic-volumes
  - /portainer/${COMPOSE_PROJECT_NAME}-mautic/config:/var/www/html/config:z
  - /portainer/${COMPOSE_PROJECT_NAME}-mautic/logs:/var/www/html/var/logs:z
  - /portainer/${COMPOSE_PROJECT_NAME}-mautic/media/files:/var/www/html/docroot/media/files:z
  - /portainer/${COMPOSE_PROJECT_NAME}-mautic/media/images:/var/www/html/docroot/media/images:z
  - /portainer/${COMPOSE_PROJECT_NAME}-cron:/opt/mautic/cron:z

services:
  # Database moved to separate stack - see percona/docker-compose.percona.yml
  # Start Percona stack FIRST before starting this stack

  rabbitmq:
    image: rabbitmq:3
    environment:
      - RABBITMQ_DEFAULT_VHOST=${RABBITMQ_DEFAULT_VHOST}
    volumes: 
      - rabbitmq-data:/var/lib/rabbitmq
    networks:
      - default

  mautic_web:
    image: mautic/mautic:6.0.7-apache
    volumes: *mautic-volumes
    environment:
      - DOCKER_MAUTIC_LOAD_TEST_DATA=${DOCKER_MAUTIC_LOAD_TEST_DATA}
      - DOCKER_MAUTIC_RUN_MIGRATIONS=${DOCKER_MAUTIC_RUN_MIGRATIONS}
    env_file:
      - .mautic_env
    healthcheck:
      test: curl http://localhost
      start_period: 10s
      interval: 10s
      timeout: 5s
      retries: 100
    networks:
      - default
      - web
      - mautic-db-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mautic-http.rule=Host(`newsletter.smartoys.be`)"
      - "traefik.http.routers.mautic-http.entrypoints=http"
      - "traefik.http.routers.mautic-http.middlewares=https-redirect"
      - "traefik.http.routers.mautic-https.rule=Host(`newsletter.smartoys.be`)"
      - "traefik.http.routers.mautic-https.entrypoints=https"
      - "traefik.http.routers.mautic-https.tls=true"
      - "traefik.http.routers.mautic-https.tls.certresolver=cloudflare"
      - "traefik.http.routers.mautic-https.middlewares=secure-headers"
      - "traefik.http.services.mautic.loadbalancer.server.port=80"
      - "traefik.docker.network=web"

  mautic_cron:
    image: mautic/mautic:6.0.7-apache
    volumes: *mautic-volumes
    environment:
      - DOCKER_MAUTIC_ROLE=mautic_cron
    env_file:
      - .mautic_env
    depends_on:
      mautic_web:
        condition: service_healthy
    networks:
      - default
      - mautic-db-network

  mautic_worker:
    image: mautic/mautic:6.0.7-apache
    volumes: *mautic-volumes
    environment:
      - DOCKER_MAUTIC_ROLE=mautic_worker
    env_file:
      - .mautic_env
    depends_on:
      mautic_web:
        condition: service_healthy
    networks:
      - default
      - mautic-db-network

volumes:
  rabbitmq-data:

networks:
  default:
    name: ${COMPOSE_PROJECT_NAME}-docker
  web:
    external: true
  mautic-db-network:
    external: true
    name: mautic-db-network
```

### Step-by-Step Deployment in Portainer

#### Correct Order:

1. **Create Network** (if not exists)
   - Portainer → Networks → Add network
   - Name: `mautic-db-network`

2. **Deploy Percona Stack FIRST**
   - Portainer → Stacks → Add stack
   - Name: `percona-db`
   - Set environment variables
   - Deploy
   - **Wait until status is Active**

3. **Verify Percona is Running**
   - Portainer → Containers → percona-db → Logs
   - Should see: "MySQL init process done. Ready for start up."

4. **Update .mautic_env**
   - Ensure `MAUTIC_DB_HOST=percona-db`

5. **Deploy Mautic Stack SECOND**
   - Portainer → Stacks → Add/Update stack
   - Use corrected docker-compose.yml (no external_links)
   - Deploy

### Testing Connection

Once deployed, test the connection:

```bash
# In Portainer: Containers → mautic_web → Console → Connect

# Test DNS resolution
ping percona-db
# Should resolve to an IP

# Test port connectivity
nc -zv percona-db 3306
# Should say "open"

# Test MySQL connection
mysql -h percona-db -u mautic -p
# Enter password, should connect
```

### Quick Fix Checklist

- [ ] Percona stack is deployed and running
- [ ] Network `mautic-db-network` exists
- [ ] `.mautic_env` has `MAUTIC_DB_HOST=percona-db`
- [ ] `docker-compose.yml` has NO `external_links`
- [ ] `docker-compose.yml` includes `mautic-db-network` in networks
- [ ] Both stacks reference the same network name
- [ ] Mautic stack deployed AFTER Percona stack

### Still Not Working?

1. **Check Percona logs:**
   ```
   Portainer → Containers → percona-db → Logs
   ```

2. **Check Mautic logs:**
   ```
   Portainer → Containers → mautic_web → Logs
   ```

3. **Check network:**
   ```
   Portainer → Networks → mautic-db-network
   ```
   Should show containers from both stacks

4. **Recreate network:**
   - Stop both stacks
   - Delete network
   - Recreate network
   - Start Percona stack
   - Start Mautic stack

### Alternative: Single Stack Deployment

If separate stacks continue to cause issues in Portainer, you can temporarily merge them:

```yaml
# Temporary single-stack deployment
services:
  db:
    build:
      context: ./percona
      dockerfile: Dockerfile.percona
    # ... rest of Percona config
  
  mautic_web:
    # ... mautic config
    depends_on:
      db:
        condition: service_healthy
```

Then migrate to separate stacks once working.
