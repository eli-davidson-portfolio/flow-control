# Development Environment Verification Checklist

## 1. Initial Verification (`verify-dev` target)

### Development Tools Check
```
=== Checking development tools ===
✓ Go version: go1.22+ detected
✓ Node.js version: v16+ detected (for web development)
✓ Required tools available:
  - git
  - make
  - sqlite3
  - jq
```

### Docker Environment Check
```
=== Checking Docker Desktop ===
✓ Docker Desktop is running
✓ Docker Compose available
✓ Docker network 'flow-control' created
✓ Docker API responsive
```

### Port Availability Check
```
=== Checking required ports ===
✓ Port 8080 available (Application)
✓ Port 9001 available (Webhooks)
```

### State Directory Check
```
=== Verifying state directory ===
✓ Directory structure created:
  - /data
  - /logs
  - /backups
✓ Write permissions verified
✓ Sufficient disk space available
```

### Resource Usage Check
```
=== Checking resource usage ===
✓ CPU usage normal (<80%)
✓ Memory usage normal (<80%)
✓ Disk usage normal (<80%)
```

### Bridge Protocol Check
```
=== Verifying bridge protocol ===
✓ SQLite database initialized
✓ Schema verified
✓ Test state saved successfully
✓ State retrieval working
```

### State Persistence Check
```
=== Testing state persistence ===
✓ State file created
✓ JSON format verified
✓ Backup created successfully
```

## 2. Go Module Initialization (`init` target)

```
=== Initializing Go module ===
✓ go.mod exists
✓ Dependencies downloaded
✓ Module tidy successful
```

## 3. Build Process (`build` target)

```
=== Building application ===
✓ Binary created: bin/flow-control
✓ No compilation errors
✓ Build artifacts in place
```

## 4. Application Startup

### Initial Banner
```
╔═══════════════════════════════════════════╗
║         Flow Control - Development        ║
╚═══════════════════════════════════════════╝
```

### Startup Logs
```
[INFO] Starting Flow Control in dev environment
[INFO] Development environment started
[INFO] Hot reload enabled
[INFO] Test framework active
[INFO] Bridge protocol initialized
```

### Service Status
```
=== Service Status ===
✓ HTTP server listening on :8080
✓ Webhook server listening on :9001
✓ Bridge protocol active
✓ Test framework ready
```

## 5. Runtime Verification

### API Health Check
```
$ curl http://localhost:8080/health
{
  "status": "healthy",
  "version": "dev",
  "timestamp": "2024-03-03T13:35:20Z"
}
```

### Webhook Health Check
```
$ curl http://localhost:9001/health
{
  "status": "healthy",
  "version": "dev",
  "timestamp": "2024-03-03T13:35:20Z"
}
```

### Log File Check
```
$ tail -f logs/dev.log
[2024-03-03 13:35:20] INFO  Starting development server
[2024-03-03 13:35:20] INFO  Hot reload enabled
[2024-03-03 13:35:20] INFO  Test framework initialized
[2024-03-03 13:35:20] INFO  Bridge protocol active
```

### State Check
```
$ sqlite3 data/test_state.db ".tables"
test_logs test_results test_state

$ sqlite3 data/test_state.db "SELECT * FROM test_state;"
[Expected state data present]
```

## 6. Hot Reload Verification

1. **File Change Detection**
```
[INFO] File change detected: internal/server/server.go
[INFO] Rebuilding...
[INFO] Build successful
[INFO] Restarting server...
```

2. **Clean Shutdown**
```
[INFO] Shutting down servers...
[INFO] Saving state...
[INFO] Cleanup complete
```

3. **Clean Startup**
```
[INFO] Starting servers...
[INFO] State restored
[INFO] Ready for connections
```

## 7. Test Framework Check

```
=== Running test framework ===
✓ L0 (Visual) tests passing
✓ L1 (Core) tests passing
✓ L2 (Environment) tests passing
✓ L3 (Operations) tests passing
✓ L5 (Application) tests passing
```

## 8. Resource Monitoring

### Docker Container Status
```
$ docker ps
CONTAINER ID   IMAGE           STATUS          PORTS
abc123...      flow-control   Up 5 minutes    0.0.0.0:8080->8080/tcp
def456...      flow-test      Up 5 minutes    0.0.0.0:9001->9001/tcp
```

### Resource Usage
```
$ docker stats
CONTAINER     CPU %     MEM %     NET I/O     DISK I/O
flow-control  < 5%      < 100MB   Active      Minimal
flow-test     < 2%      < 50MB    Active      Minimal
```

## 9. Shutdown Verification

### Clean Shutdown Signals
```
^C received, shutting down gracefully...
[INFO] Saving application state...
[INFO] Closing database connections...
[INFO] Stopping test framework...
[INFO] Cleanup complete
```

### Post-Shutdown State
```
✓ No lingering processes
✓ Ports released
✓ State saved
✓ Logs rotated
```

## Common Issues and Expected Solutions

1. **Port Conflicts**
```
[ERROR] Port 8080 is not available
Solution: Stop conflicting service or change port in config/dev/.env.dev
```

2. **Docker Issues**
```
[ERROR] Docker Desktop is not running
Solution: Start Docker Desktop and retry
```

3. **Permission Issues**
```
[ERROR] No write permission in state directory
Solution: Check directory permissions and ownership
```

4. **Resource Issues**
```
[WARNING] High resource usage detected
Solution: Free up system resources or adjust thresholds
```

## Success Criteria

1. **All Verification Steps Pass**
   - No errors in verification phase
   - All services start successfully
   - Test framework operational

2. **System Health**
   - All ports accessible
   - Resources within limits
   - State persistence working

3. **Development Features**
   - Hot reload functioning
   - Test framework responsive
   - Bridge protocol operational

4. **Monitoring**
   - Logs being generated
   - Metrics being collected
   - State being tracked

## Recovery Procedures

1. **Failed Verification**
```bash
# Clean state and retry
$ make clean
$ rm -rf data/*
$ make dev
```

2. **Stuck Services**
```bash
# Force cleanup and restart
$ docker-compose down
$ killall flow-control
$ make dev
```

3. **Corrupt State**
```bash
# Restore from backup
$ ./scripts/verify/common/state.sh restore_state \
    backups/state_<timestamp>.tar.gz \
    data/
```