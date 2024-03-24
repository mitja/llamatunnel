# Llama Tunnel

## Publish Local LLMs and Apps on the Internet

With Llama Tunnel, you can publish your local LLM APIs and apps on the internet so that you can use your local LLMs and LLM apps on the go and share them with friends.

The services are also published locally with TLS certificates for the same domain name. When you configure a local DNS server to resolve the domain name to the local IP address of the machine running the services, you can use the services at home within your local network without changing the domain name.

## Get Started with Cloudflare Tunnels

Prerequisites are:

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Ollama](https://ollama.com) installed on your machine and running on http://localhost:11434
- a [Cloudflare](https://www.cloudflare.com/) account
- a domain mangaged with Cloudflare DNS
- [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) installed on your machine. You can install it with `brew install cloudflare/cloudflare/cloudflared` on macOS or `winget install --id Cloudflare.cloudflared` on Windows. For linux, use the package manager of your distribution.
- [Python](https://www.python.org/downloads/) 3.8 or newer
- [Git](https://git-scm.com) 2.27 or newer
- [pipx](ttps://github.com/pypa/pipx) - a package manager for Python tools, also installable with `brew install pipx` on macOS. On Windows, you can install it with Scoop (see below).
- [copier](https://copier.readthedocs.io/en/stable/) (you can install it with `pipx install copier`) - a tool to start projects based on templates

Install Scoop and pipx on Windows:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -scope CurrentUser
Invoke-RestMethod -Uri "https://get.scoop.sh" | Invoke-Expression
scoop install pipx
```

Create a Cloudflare API token with the permissions to modify the DNS zone. This is needed for the Caddy DNS challenge. Go to the Cloudflare dashboard and create a token as follows:

`My Profile` > `API Tokens` > `Create Token` > `Edit Zone DNS` > `Zone:DNS:Edit` > `Include:Specific Zone:<DOMAIN_NAME>` > `Continue to Summary` > `Create Token`

On you local machine, login with cloudflared:

```bash
cloudflared tunnel login
```

Create a tunnel and DNS routes for the services. `cloudflared tunnel create` returns a tunnel id. Please note it as you will need it later.

macOS and Linux:

```bash
TUNNEL_NAME="llamatunnel"
DOMAIN_NAME="example.com"
API_SUBDOMAIN="api"
APP_SUBDOMAIN="app"
cloudflared tunnel create --credentials-file credentials.json $TUNNEL_NAME
cloudflared tunnel route dns $TUNNEL_NAME $API_SUBDOMAIN.$DOMAIN_NAME
cloudflared tunnel route dns $TUNNEL_NAME $APP_SUBDOMAIN.$DOMAIN_NAME
```

Windows:

```powershell
$TUNNEL_NAME="llamatunnel"
$DOMAIN_NAME="example.com"
$API_SUBDOMAIN="api"
$APP_SUBDOMAIN="app"
cloudflared tunnel create --credentials-file credentials.json $TUNNEL_NAME
cloudflared tunnel route dns $TUNNEL_NAME $API_SUBDOMAIN.$DOMAIN_NAME
cloudflared tunnel route dns $TUNNEL_NAME $APP_SUBDOMAIN.$DOMAIN_NAME
```

Note that you cannot manage this tunnel on the Cloudflare Dashboard but need to use the `cloudflared` CLI tool to manage the tunnel and the DNS routing, otherwise you won't get the `credentials.json` file which is required to authenticate the `cloudflared` service.

Create the project from the template with copier and answer the questions. If you forgot the tunnel id, you can find it in the `credentials.json` file or with `cloudflared tunnel list`.

macOS and Linux:

```bash
DOCKER_STACKS_DIR="$HOME/docker-stacks"
copier gh:mitja/llamatunnel $DOCKER_STACKS_DIR
```

Windows:

```powershell
$DOCKER_STACKS_DIR="$HOME\docker-stacks"
copier gh:mitja/llamatunnel $DOCKER_STACKS_DIR
```

This will create a new directory in the `DOCKER_STACKS_DIR` with the all the files necessary to run the tunnel.

Create data directory for cloudflared and copy the credentials file to this data directory. The following example assumes that you have left the data directory at the default location which is `./data` in the project directory. If you have changed the location of the data directory, you need to adjust the path accordingly.

macOS and Linux:

```bash
DOCKER_STACKS_DIR="$HOME/docker-stacks"
PROJECT_NAME="testtunnel"
DATA_DIR="$DOCKER_STACKS_DIR/$PROJECT_NAME/data"
mkdir -p $DATA_DIR/cloudflared
cp credentials.json $DATA_DIR/cloudflared/credentials.json
```

Windows:

```powershell
DOCKER_STACKS_DIR="$HOME\docker-stacks"
PROJECT_NAME="testtunnel"
DATA_DIR="$DOCKER_STACKS_DIR\$PROJECT_NAME\data"
mkdir -p $DATA_DIR\cloudflared
cp credentials.json $DATA_DIR\cloudflared\credentials.json
```

Change into the project directory and start the services:

macOS and Linux:

```bash
DOCKER_STACKS_DIR="$HOME/docker-stacks"
PROJECT_NAME="llamatunnel"
cd $DOCKER_STACKS_DIR/$PROJECT_NAME
docker-compose up -d --build
```

Windows:

```bash
DOCKER_STACKS_DIR="$HOME\docker-stacks"
PROJECT_NAME="llamatunnel"
cd $DOCKER_STACKS_DIR\$PROJECT_NAME
docker-compose up -d --build
```

Now you can use Ollama at `https://api.example.com` and OpenWebUI `https://app.example.com` (assuming you use app and api as subdomains).

## Solution Overview

This project uses **Docker Compose** to start cloudflared, Caddy, and OpenWebUI and **Cloudflare Tunnels** to route traffic from the internet to Ollama and OpenWebUI on your local machine.

By default,

- api.example.com points to your local Ollama (which should already be installed on your machine)
- app.example.com points to your local OpenWebUI

Cloudflared:

- Creates an outbound-only connection to Cloudflare’s global network.
- Forwards traffic only to the local Caddy service. Ollama and OpenWebUI are not directly exposed to the internet.

Caddy:

- Acts as a reverse proxy.
- Protects the Ollama API with a configurable API key.
- Serves on https with SSL certificates for the same domain name. Thus, you can use a local DNS server to access the services from your local network without going over the internet.

OpenWebUI:

- Is a chat app that uses the OpenAI API to create a chat experience.
- Directly talks to the local Ollama, without going over the internet or Caddy.

Ollama:

- Uses llama.cpp to run large language models on your local machine and expose them with an OpenAI compatible API.
- Should already be installed directly on your machine and listen on http://localhost:11434 (the default configuration).

Docker Compose:

- Manages multiple Docker containers in a single yaml file andå with a single command.
- Encapsulates the services in a user-defined network, so that they can communicate with each other over an internal DNS.
- Maps the ports of the Caddy and OpenWebUI services to the host system, so that you can also access the services from your local machine or your local network.
- Requires that Docker Desktop or something similar is installed on your machine.

After setup, you can start the services with

```bash
docker-compose up -d --build
```

## FAQ

### What are the Benefits of Using Cloudflare Tunnels to publish my local LLM Services on the Internet?

In principle, you can publish your local services on the internet in three different ways:

| Method | Pros | Cons |
| --- | --- | --- |
| VPN with Dynamic DNS | Secure, private, and encrypted connection | gives access to your network, you need to open the tunnel to use the services |
| Open ports with Dynamic DNS | Easy to set up, no need for a VPN | you need to open ports on your router, needs additional security measures in your network, could be blocked by your internet service provider |
| Outbound tunnel to a gateway service on the internet | no need to open ports on your home network, can be shared with friends without handing out VPN access to your network, you can authenticate/authorize outside of your network | you need a service on the internet |

An outbound tunnel is a great compromise between security, convenience, and shareability.

[Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) is just one of many services you can use for outbound tunnels. The benefit is that it's free if you already have a domain you can use for this. The main drawbacks of Cloudflare Tunnels are the complex setup, and some limitations of the service. Also, it would be more secure to perform pre-authentication of API clients and users outside of your network. Cloudflare supports this with the Zero Trust Access service, but this can get quite expensive.

### Why Do You Install cloudflared as CLI Tool?

I use cloudflared as cli tool for administrative tasks and not run them in the docker container defined in docker-compose.yaml. This way, I don't need to make the admin credentials available to the cloudflared service.

### What if I have a Firewall?

If you have a firewall, you need to allow outbound connections to the Cloudflare network form the machine you run the solution on. You can find the DNS names and ports in the Cloudflare [Tunnel with firewall](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/tunnel-with-firewall/) documentation.

### Why and How Do You Build a Custom Docker Image for Caddy?

The custom Caddy image adds the Cloudflare module for the DNS challenge to Caddy which is not built into Caddy by default. Creating a custom Caddy binary and package it in an image can be done with a Docker [Multi-stage build](https://docs.docker.com/build/building/multi-stage/):

- The first stage uses Caddy's builder image and runs the `xcaddy` command to build caddy with the Cloudflare module.
- The second stage create a new image and copies the resulting binary from the builder into it.

Here is the Dockerfile, you can find it in  `./images/caddy/Dockerfile`:

```Dockerfile
FROM caddy:2.7.6-builder AS builder
RUN xcaddy build --with github.com/caddy-dns/cloudflare
FROM caddy:2.7.6
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
```

If you want to learn more about this, You can find a description of the procedure in the [Caddy Image Overview](https://hub.docker.com/_/caddy) on Docker Hub (scroll down to the "Adding custom Caddy modules" section).

### What Do You Use to Edit the Caddyfile?

I use Visual Studio Code with the [Caddyfile Support](https://marketplace.visualstudio.com/items?itemName=matthewpi.caddyfile-support) extension for Visual Studio Code to get syntax highlighting, suggestions, and documentation hints for Caddyfiles.

### Can I Publish the Services Deeper Level Subdomain like ollama.home.example.com?

If you want to proxy a wildcard DNS record on a deeper level like `*.local.example.com` you can subscribe to [Cloudflare Advanced Certificate Manager](https://developers.cloudflare.com/ssl/edge-certificates/advanced-certificate-manager/). For more information, see the Cloudflare Blog post [Wildcard proxy for everyone](https://blog.cloudflare.com/wildcard-proxy-for-everyone) by Hannes Gerhart.

### How Can I Add Monitoring and Logging?

You can start all services with a monitoring endpoint that exposes Prometheus metrics. You can use the Prometheus and Grafana Docker images to monitor the services. Here are some links to get started:

- [Cloudflare Tunnel Metrics](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/monitor-tunnels/metrics/)
- [Monitoring Caddy with Prometheus Metrics](https://caddyserver.com/docs/metrics)
- Thibault Debatty: [Use Loki to monitor the logs of your docker compose application](https://cylab.be/blog/241/use-loki-to-monitor-the-logs-of-your-docker-compose-application)

For `cloudflared`, you can use the `--loglevel debug` option to get more detailed logs.

You can also use the Cloudflare Tunnel logs to monitor the tunnel and the DNS routing.

### Why Don't You Use DNSSEC?

I don't use DNSSEC in this setup because I want to use the same domain name for local and public access with a local DNS server that resolves the domain to the local IP address. While this is possible to implement with DNSSEC, I have not tried it and I believe it is also quite hard to do.

If you don't want to use the services locally with the same domain name, you can probably activate DNSSEC on your domain. If you do, I would like to hear about your experience, as I haven't tried it yet.

### Can I Control the Geographic Region of the Cloudflare Tunnel?

While you can theoretically use the `--region` option to specify the region to which the tunnel connects, the only available value is `us` which routes all connections through data centers in the United States. 

When you omit this option or leave it empty you connect to the global region. So in effect, you cannot control in which region to run the tunnels, except for the global region or the us region.

Reference: [Cloudflare Tunnel Run Parameters](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/tunnel-run-parameters/#region)

### How Can I Troubleshoot the Cloudflare Tunnel?

You can set a verbose log level and run tunnels with test commands. See the Cloudflare docs for [Locally Managed Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/local-management/) for more information.

### How Can I Contribute or Give Feedback?

If you have any questions, suggestions, or improvements, feel free to open an issue or a pull request.

### How Can I Raise as Security Issue?

Please follow GitHub's general instructions to [privately report a security vulnerability](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability#privately-reporting-a-security-vulnerability).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
