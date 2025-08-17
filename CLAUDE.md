# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Llama Tunnel is a Docker Compose-based solution that publishes local LLM APIs (Ollama) and apps (OpenWebUI) on the internet using Cloudflare Tunnels. It's implemented as a Copier template that generates configured instances.

## Architecture

### Core Components
- **Cloudflared**: Creates outbound-only tunnels to Cloudflare's network
- **Caddy**: Reverse proxy with TLS termination and API key authentication
- **OpenWebUI**: Chat interface that connects to local Ollama
- **Ollama**: LLM API server (installed separately on host machine)

### Template System
- Uses Copier for project generation and updates
- Jinja2 templates for configuration files (`.jinja` extension)
- Variables defined in `copier.yml` with user prompts
- Generated instances exclude template files via `_exclude` configuration

### Network Flow
1. Internet traffic → Cloudflare Tunnels → cloudflared container
2. cloudflared → Caddy (reverse proxy with TLS/auth)
3. Caddy → OpenWebUI container or host Ollama API
4. OpenWebUI → host Ollama API directly (bypasses tunnel)

## Common Commands

### Template Development
```bash
# Install copier with uv (single command)
uv tool install copier

# Generate a new project instance from template
copier copy . /path/to/new-instance

# Update existing instance (must be in target directory)
copier update

# Update to specific version
copier update --vcs-ref tags/0.1.7
```

### Docker Operations
```bash
# Build and start services
docker-compose up --build

# Start in detached mode
docker-compose up --build -d

# Stop services
docker-compose down

# View logs
docker-compose logs
docker-compose logs <service-name>
```

### Cloudflare Tunnel Management
```bash
# Create tunnel and credentials
cloudflared tunnel create --credentials-file ./data/cloudflared/credentials.json <tunnel-name>

# Create DNS routes
cloudflared tunnel route dns <tunnel-name> <subdomain>.<domain>

# List tunnels
cloudflared tunnel list

# Test tunnel configuration
cloudflared tunnel --config /path/to/config.yml run --loglevel debug
```

## File Structure

### Template Files (`.jinja`)
- `docker-compose.yml.jinja`: Main Docker Compose configuration
- `conf/cloudflared/config.yaml.jinja`: Cloudflared tunnel configuration
- `{{_copier_conf.answers_file}}.jinja`: Generated answers file for updates

### Configuration
- `copier.yml`: Template questions and configuration
- `conf/caddy/Caddyfile`: Caddy reverse proxy rules
- `conf/caddy/401.json`: Unauthorized response for protected API
- `images/caddy/Dockerfile`: Custom Caddy build with Cloudflare DNS module

### Data Directory
- `data/cloudflared/`: Tunnel credentials and certificates
- `data/caddy/`: Caddy data and certificates
- `data/open-webui/`: OpenWebUI persistent data

## Security Notes

### Protected Resources
- Ollama API protected by bearer token authentication in Caddy
- Cloudflare API token required for DNS challenges
- WebUI secret key for session management

### Secrets Management
- Secrets stored in `.env` file (not committed to git)
- Template generates random keys using Jinja2 filters
- Credentials file contains tunnel authentication

### File Exclusions
Template excludes: `docs/`, `data/`, `.git/`, copier files, Python cache files, and system files.

## Development Workflow

1. Modify template files (`.jinja` extensions)
2. Test by generating new instance with `copier copy`
3. Verify Docker Compose services start correctly
4. Test tunnel connectivity and authentication
5. Update documentation if architectural changes made

## Troubleshooting

### Common Issues
- Missing credentials file: Ensure `cloudflared tunnel create` was run
- DNS resolution failures: Verify Cloudflare API token permissions
- TLS certificate issues: Check Cloudflare DNS module in custom Caddy build
- Service communication: Verify Docker network configuration and `extra_hosts`

### Debug Commands
```bash
# Verbose cloudflared logging
cloudflared tunnel --config /etc/cloudflared/config.yml run --loglevel debug

# Check Caddy configuration
docker-compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# View service logs
docker-compose logs -f <service-name>
```