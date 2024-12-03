# Project Structure

## Overview
The Flow Control project follows a standard Go project layout with additional directories for configuration, documentation, and development tools.

## Directory Structure

```
flow-control/
├── .github/           # GitHub Actions and workflows
├── cmd/              # Main applications
├── internal/         # Private application and library code
├── pkg/              # Public library code
├── web/              # Web application specific code
├── docs/             # Documentation files
│   ├── api/          # API documentation
│   ├── architecture/ # Architecture decisions and diagrams
│   └── notes/        # Project notes and updates
├── config/           # Configuration files
│   ├── dev/         # Development environment configs
│   └── staging/     # Staging environment configs
├── scripts/          # Scripts for development and CI
│   ├── lib/         # Shared script libraries
│   ├── verify/      # Environment verification
│   └── ops/         # Operational scripts
├── tests/           # Additional test code and test data
├── build/           # Compiled files and build artifacts
├── vendor/          # Project dependencies
└── tmp/             # Temporary files
```

## Key Directories

### Source Code
- `cmd/`: Contains the main applications of the project
- `internal/`: Private application and library code
- `pkg/`: Library code that may be used by external applications
- `web/`: Web application specific code and assets

### Configuration
- `config/`: Environment-specific configuration files
- `.flowcontrol/`: Application-specific configuration
- `build/`: Build configurations and scripts

### Development
- `scripts/`: Development, build, and operational scripts
- `tests/`: Additional test suites and test data
- `docs/`: Project documentation and notes

### Data and State
- `data/`: Application data files
- `logs/`: Application and development logs
- `backups/`: Backup files and scripts

### Build and Dependencies
- `build/`: Compiled files
- `vendor/`: Vendored dependencies
- `bin/`: Compiled binaries
- `tmp/`: Temporary build files

## File Naming Conventions

1. Configuration Files:
   - Environment configs: `.env.<environment>`
   - Application configs: `config.<format>`
   - Docker configs: `docker-compose.<environment>.yml`

2. Documentation:
   - Architecture: `ADR-XXX-description.md`
   - Notes: `NOTES-YYYY-MM-DD.md`
   - API: `api-v<version>.md`

3. Scripts:
   - Shell scripts: `<purpose>.sh`
   - Test scripts: `test_<component>.sh`
   - Verification: `verify_<component>.sh`

## Best Practices

1. Keep the root directory clean
2. Use appropriate subdirectories for different types of files
3. Follow Go project layout standards
4. Maintain clear separation between public and private code
5. Keep configuration separate from code
6. Document architectural decisions
7. Version control appropriate files only 