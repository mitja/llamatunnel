# Llama Tunnel

## Publish Local LLMs and Apps on the Internet

With Llama Tunnel, you can publish your local LLM APIs and apps on the internet with Cloudflare Tunnels. This way, you can use your local LLMs and LLM apps on the go and share them with your friends.

See the setup section below to learn how to set it up.

## Overview

This project uses **Docker Compose** to start cloudflared, Caddy, and OpenWebUI and **Cloudflare Tunnels** to route traffic from the internet to Ollama and OpenWebUI on your local machine. 

By default,

- ollama.yourdomain.com points to your local Ollama (which should already be installed on your machine)
- chat.yourdomain.com points to your local OpenWebUI

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

## Setup

### Prerequisites

Ollama and Docker Desktop need to be already installed on your machine. You also need a domain and a Cloudflare account and you need to use Cloudflare DNS as your primary DNS provider for this domain if you want to use this solution as is.

Check out the Cloudflare DNS documentation for [Change your nameservers (Full setup)](https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/) to learn how to make Cloudflare the main DNS provider.

### Install `cloudflared` and login with your Cloudflare account

Install on MacOS:

```bash
brew install cloudflared
```

Install on Windows:

```powershell
winget install --id Cloudflare.cloudflared
```

For linux, use the package manager of your distribution. See the [Cloudflared Download Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) to learn how to install it on your system.

Then login with the following command. This will open a browser window where you can log in with your Cloudflare account.

```bash
cloudflared tunnel login
```

During login, a browser is opened (or you can open it manually with the url printed by the command). Logon to the Cloudflare Dashboard, and then authorize Cloudflare Tunnel for one of your domains. This is the `$DOMAIN_NAME` you want to use for the services.

On Windows you need to start a new shell to use the `cloudflared` command after installation.

### Create a Cloudflare API Token

Go to the Cloudflare Dashboard, create a new API token with the permissions to modify the DNS zone:

`My Profile` > `API Tokens` > `Create Token` > `Edit Zone DNS` > `Zone:DNS:Edit` > `Include:Specific Zone:<DOMAIN_NAME>` > `Continue to Summary` > `Create Token`

Note that this API Token is different than the more powerful API token you get by running `cloudflared tunnel login`. The rights of the DNS token are limited as it's only needed for Caddy to solve the Let's Encrypt's ACME DNS challenge.

### Configure Environment Variables

Copy the `.env.example` file to `.env` and set the `CLOUDFLARE_API_TOKEN`, `TUNNEL_NAME`, and `DOMAIN_NAME` variables. Also, create secrets for the `API_KEY` and the `WEBUI_SECRET_KEY` as described in the `.env` file.

### Create a Tunnel and DNS Routing

Create a cloudflared tunnel with `cloudflared tunnel create` and redirect the DNS to the tunnel with `cloudflared tunnel route dns`.

On Mac and Linux:

```bash
source .env
cloudflared tunnel create \
  --credentials-file $DATA_DIR/cloudflared/credentials.json \
  $TUNNEL_NAME
cloudflared tunnel route dns $TUNNEL_NAME ollama.$DOMAIN_NAME
cloudflared tunnel route dns $TUNNEL_NAME chat.$DOMAIN_NAME
```

On Windows, you can run the following commands (with `llm` as example tunnel name and `example.com` as example domain - use you own domain and tunnel name):

```powershell
$TUNNEL_NAME="llm"
$DOMAIN_NAME="example.com"
$DATA_DIR="./data"
cloudflared tunnel create --credentials-file $DATA_DIR/cloudflared/credentials.json $TUNNEL_NAME
cloudflared tunnel route dns $TUNNEL_NAME ollama.$DOMAIN_NAME
cloudflared tunnel route dns $TUNNEL_NAME chat.$DOMAIN_NAME
```

Note that you cannot manage this on the Cloudflare Dashboard. You need to use the `cloudflared` CLI tool to manage the tunnel and the DNS routing, otherwise you won't get the `credentials.json` file which is needed to authenticate the `cloudflared` service.

### Configure the cloudflared Service

On Mac or Linux, run the following script to create the `./conf/cloudflared/config.yaml` file based on a template:

```bash
source .env
source ./write_cloudflared_config.sh
```

On Windows, you can either:

- run the above command in WSL2,
- or create the `./conf/cloudflared/config.yaml` file by hand,
- or run following commands in PowerShell:

First, install `sed` and `jq` as PowerShell commandlets:

```powershell
winget install --id jqlang.jq
winget install --id mbuilov.sed
```

Then, run the following commands to create the `./conf/cloudflared/config.yaml` file:

```powershell
TUNNEL_ID=cat $DATA_DIR/cloudflared/credentials.json | jq '.TunnelID'
sed "s/TUNNEL_ID/$TUNNEL_ID/g;s/DOMAIN_NAME/$DOMAIN_NAME/g" \
  ./conf/cloudflared/config.tpl.yaml \
  > ./conf/cloudflared/config.yaml
```

### Start the Services

```bash
docker-compose up -d --build
```

### Test It

Test if you can reach services with a web browser:

Test Ollama at `https://ollama.$DOMAIN_NAME/api/generate` (you should see a 401 error as you don't provide a valid `API_KEY`). To test with a valid `API_KEY`, use curl:

```bash
source .env
curl -H "Authorization: Bearer $OLLAMA_API_KEY" -v https://ollama.$DOMAIN_NAME/api/generate -d '{
  "model": "llama2",
  "prompt": "Why is the sky blue?"
}'
```

Test OpenWebUI at `https://chat.$DOMAIN_NAME`. Create an account - the first account will be the administrator. Then, you can use the chat app.

If you want to test the tunnel and the DNS routing in isolation, you can start `cloudflared` and `caddy`, with Caddy being configured to respond a simple test text.

```bash
`docker-compose up -d --build -f docker-compose.tunnel-test.yml`
```

## FAQ

### What are the Benefits of Using Cloudflare Tunnels to publish my local LLM Services on the Internet?

In principle, you can publish your local LLM and LLM apps on the internet with three different methods:

| Method | Pros | Cons |
| --- | --- | --- |
| VPN | Secure, private, and encrypted connection | gives access to your network, you need to open the tunnel to use the services |
| Dynamic DNS | Easy to set up, no need for a VPN | you need to open the tunnel to use the services, not as secure, could be blocked by your internet service provider |
| Outbound tunnel to a reverse proxy service on the internet | no need to open ports on your home network, can be shared with friends without sharing complete VPN access to your network, you can authenticate/authorize outside of your network | you need a service on the internet |

An outbound tunnel is probably the best compromise of security, convenience of use, and shareability.

[Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) is just one of many services you can use for outbound tunnels. The benefit is that it's free if you already have a domain you can use for this. The main drawbacks of Cloudflare Tunnels are the complex setup, and some limitations of the service. Also, it would be more secure to perform pre-authentication of API clients and users outside of your network. Cloudflare supports this with the Zero Trust Access service, but this can get quite expensive.

### Where Can I find a more Detailed Description?

For a more in-dept description of how this works, check out my blog post.

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

This is not possible with the free Cloudflare account. If you want to proxy a wildcard DNS record on a deeper level like `*.local.example.com` you can subscribe to [Cloudflare Advanced Certificate Manager](https://developers.cloudflare.com/ssl/edge-certificates/advanced-certificate-manager/). For more information, see the Cloudflare Blog post [Wildcard proxy for everyone](https://blog.cloudflare.com/wildcard-proxy-for-everyone) by Hannes Gerhart.

### How Can I Add Monitoring and Logging?

You can start all services with a monitoring endpoint that exposes Prometheus metrics. You can use the Prometheus and Grafana Docker images to monitor the services. Here are some links to get started:

- [Cloudflare Tunnel Metrics](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/monitor-tunnels/metrics/)
- [Monitoring Caddy with Prometheus Metrics](https://caddyserver.com/docs/metrics)
- Thibault Debatty: [Use Loki to monitor the logs of your docker compose application](https://cylab.be/blog/241/use-loki-to-monitor-the-logs-of-your-docker-compose-application)

For `cloudflared`, you can use the `--loglevel debug` option to get more detailed logs.

You can also use the Cloudflare Tunnel logs to monitor the tunnel and the DNS routing.

### Why Don't You Use DNSSEC?

I don't use DNSSEC in this setup because I want to use the same domain name for local and public access with a local DNS server that resolves the domain to the local IP address. While this is possible to implement with DNSSEC, I have not tried it and I believe it is also quite hard to do. If you don't want to use the services locally with the same domain name, you can probably activate DNSSEC on your domain. If you do, I would like to hear about your experience, as I haven't tried it yet.

### Can I Control the Geographic Region of the Cloudflare Tunnel?

While you can theoretically use the `--region` option to specify the region to which the tunnel connects, the only available value is `us` which routes all connections through data centers in the United States. Omit or leave the option empty to connect to the global region. So in effect, you cannot control in which region to run the tunnels, except for the global or the us region.

Reference: [Cloudflare Tunnel Run Parameters](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/tunnel-run-parameters/#region)

### How Can I Troubleshoot the Cloudflare Tunnel?

You can set a verbose log level and run tunnels with test commands. See the Cloudflare docs for [Locally Managed Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/local-management/) for more information.

## Detailed Description

### Install Cloudflared and login

I use the cloudflared as a CLI tool to perform the administrative tasks.

This is how you can install it on macOS with Homebrew:

```bash
brew install cloudflare/cloudflare/cloudflared
```

On Windows:

```powershell
winget install --id Cloudflare.cloudflared
```

To learn how to install it on other systems, see the [Cloudflared Download Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/).

Then login with the following command. This will open a browser window where you can log in with your Cloudflare account:

```bash
cloudflared tunnel login
```

### Create a Cloudflare API token for DNS Zone Editing

Create a Cloudflare API token with the permissions to modify the DNS zone. This is needed for the Caddy DNS challenge. Go to the Cloudflare dashboard and create a token as follows:

`My Profile` > `API Tokens` > `Create Token` > `Edit Zone DNS` > `Zone:DNS:Edit` > `Include:Specific Zone:<DOMAIN_NAME>` > `Continue to Summary` > `Create Token`

Then, create an `.env` file by copying the `.env.example` file:

```bash
cp .env.example .env
```

Copy the token from the Cloudflare Dashboard and save it to the `.env` file. Also set the `TUNNEL_NAME` and `DOMAIN_NAME` variables in the `.env` file:

```bash
CLOUDFLARE_API_TOKEN="<the-token>"
TUNNEL_NAME="mbp"
DOMAIN_NAME="<the-domain-name>"
```

### Create a Tunnel

You can create a tunnel with following commands:

```bash
source .env
cloudflared tunnel create \
  --credentials-file $DATA_DIR/cloudflared/credentials.json \
  $TUNNEL_NAME
```

This will create a tunnel with the name $TUNNEL_NAME and save the credentials to the `$DATA_DIR/cloudflared/credentials.json` file. The credentials file is used to authenticate the `cloudflared` service and also contains the `TunnelID` which we'll need later.

Note: **Don't** add the credentials file to your git repository. In fact: You should `.gitignore` the whole `$DATA_DIR` directory.

### Configure DNS routing

Configure DNS names to point to the cloudflared tunnel. See [Cloudflare Routing DNS to Tunnel docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/routing-to-tunnel/dns/).

I created two routes for the tunnel, one for Ollama, one for a chat app (OpenWebUI):

```bash
cloudflared tunnel route dns $TUNNEL_NAME ollama.$DOMAIN_NAME
cloudflared tunnel route dns $TUNNEL_NAME chat.$DOMAIN_NAME
```

### Configure the Caddyfile for the DNS Challenge and Test Responses

Configure the DNS challenge, named matchers, and handlers in the `Caddyfile`. You can have a look at the `./conf/caddy/simple-response/Caddyfile` to see the configuration. This is used in the next step to test the tunnel and the DNS routing:

```yaml
*.{$DOMAIN_NAME}:443 {

  tls {
    dns cloudflare {$CLOUDFLARE_API_TOKEN}
    resolvers 1.1.1.1
  }

  @chat {
    host chat.{$DOMAIN_NAME}
  }

  @ollama {
    host ollama.{$DOMAIN_NAME}
  }

  handle @ollama {
    respond @ollama "hi from ollama.{$DOMAIN_NAME}"
  }

  handle @chat {
    respond @chat "hi from chat.{$DOMAIN_NAME}"
  }
}
```

### Configure the Cloudflare Tunnel

Now configure the `cloudflared` service with hostname ingresses.

You can quickly create a configuration file for the `cloudflared` container with the following command:

```bash
source .env
source ./write_cloudflared_config.sh
```

This uses the template at `./conf/cloudflared/config.tpl.yaml` and replaces the `DOMAIN_NAME` placeholder with the variable from the `.env` file and the `TUNNEL_ID` placeholder with the value of `TunnelID` from the `./data/cloudflared/credentials.json` file and saves the result in a newly created `./conf/cloudflared/config.yaml` file. You can also manually create the `./conf/cloudflared/config.yaml` file by doing the same.

The `write_cloudflared_config.sh` script looks like this:

```bash
TUNNEL_ID="`cat $DATA_DIR/cloudflared/credentials.json | jq '.TunnelID'`"
sed "s/TUNNEL_ID/$TUNNEL_ID/g;s/DOMAIN_NAME/$DOMAIN_NAME/g" \
  ./conf/cloudflared/config.tpl.yaml \
  > ./conf/cloudflared/config.yaml
```

Here is the content of the `./conf/cloudflared/config.tpl.yaml` file. If you want to create the `./conf/cloudflared/config.yaml` by hand, you need to replace `TUNNEL_ID` with the id of your tunnel and the `DOMAIN_NAME` with your own domain name. Be sure to use the tunnel **id** here, as the tunnel name doesn't work in the `cloudflared` configuration file:

```yaml
tunnel: TUNNEL_ID
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: 'chat.DOMAIN_NAME'
    service: https://caddy:443
    originRequest:
      originServerName: '*.DOMAIN_NAME'
      # noTLSVerify: true
      # disableChunkedEncoding: true
  - hostname: 'ollama.DOMAIN_NAME'
    service: https://caddy:443
    originRequest:
      originServerName: '*.DOMAIN_NAME'
  - service: http_status:404 # default service
```

I want to create two ingresses, one ingress for Ollama and one ingress for the chat app. `service` points to the upstream server name. I will call the Docker container `caddy`, this is why I can set `service` to `https://caddy:443`.

The `originRequest` section is optional, but needed in this case to make sure that the TLS handshake works. The value of `originServerName` tells `cloudflared` the server name of the TLS certificate. As Caddy is requesting a wildcard certificate for the `$DOMAIN_NAME`, I can set it to `*.$DOMAIN_NAME`. Alternatively, you could also set `noTLSVerify` to `true` to disable TLS verification.

The `disableChunkedEncoding` helps with some WSGI apps. Here, this is not needed, but I left it in the template as a comment. The `ingress` section ends with an obligatory catch service which returns a `404` error. This is the default service if no other service matches the request.

### Launch cloudflared and Caddy with Docker Compose

At this point, you can test if the tunnel and the DNS routing work. Take a look at `docker-compose.tunnel-test.yml`. This starts the `cloudflared` tunnel and Caddy with the Caddyfile in `./conf/caddy/simple-response`:

```yaml
version: '3'

networks:
  web:
    driver: bridge

services:
  #--- Caddy ---
  caddy:
    build:
      context: ./images/caddy
      dockerfile: ./Dockerfile
    restart: unless-stopped
    environment:
      - CLOUDFLARE_API_TOKEN=${CLOUDFLARE_API_TOKEN}
      - DOMAIN_NAME=${DOMAIN_NAME}
    volumes:
      - ./conf/caddy/simple-response/Caddyfile:/etc/caddy/Caddyfile
      - ${DATA_DIR-./data}/caddy:/data/caddy
    ports:
      - "443:443"
    networks:
      - web
  #--- Cloudflared ---
  cloudflared:
    image: cloudflare/cloudflared
    restart: unless-stopped
    depends_on:
      - caddy
    volumes:
      - ./conf/cloudflared/config.yaml:/etc/cloudflared/config.yml
      - ${DATA_DIR-./data}/cloudflared/credentials.json:/etc/cloudflared/credentials.json
    command: tunnel --config /etc/cloudflared/config.yml run #--loglevel debug run 
    networks:
      - web
```

the **web network** is created with the [Bridge Network driver](https://docs.docker.com/network/drivers/bridge/). As this is a user defined network, DNS resolution between containers is supported. It also provides a scoped network, which means, only containers in the same network can communicate with each other.

The **Caddy service** is based on a custom Docker image to include the Caddy module for the Cloudflare DNS acme challenge, which is not included in the default Caddy docker image.

the **volumes** bind the `Caddyfile` and the `caddy` data directory to the container. You should make sure to not commit the data directory to git as it contains the private keys for TLS certificate and the cloudflared credentials.

Port **443** is mapped to the host system. This way, you can also reach the services from your local machine or your local network without going over the Internet.

The **cloudflared** service depends on the caddy service, binds the `config.yaml` and `credentials.json` files to the container, and runs the `tunnel` command with the `run` option.

Start the service in the foreground with `docker-compose up`.

Test if it works by browsing to the domains (https://chat.$DOMAIN_NAME, https://ollama.$DOMAIN_NAME). You should see the "hi from chat.$DOMAIN_NAME" and "hi from ollama.$DOMAIN_NAME" messages. Alternatively, you can also use `curl` in another terminal to test the services:

```bash
curl -k https://chat.$DOMAIN_NAME
curl -k https://ollama.$DOMAIN_NAME
```

You can also use the service from the local machine and the local network with the public domain name. As Caddy presents a TLS certificate for the public domain name that's signed by Let's Encrypt, your browser and other clients will most probably trust the certificate.

If you have a local DNS server which you can configure, you can use the services both at home and on the go via internet without changing anything on the client side. Just point the $DOMAIN_NAME to the local network ip where Caddy is running. From then on requests will directly be served by the local service without going over the Internet when you are in your local home network.

You can test this `curl` even if you don't have a configurable DNS server with the `--resolve` switch:

```bash
curl --resolve 'ollama.$DOMAIN_NAME:443:127.0.0.1' \
-v https://ollama.$DOMAIN_NAME
```

The `--resolve` switch tells curl to resolve the domain to the local IP address. Be sure to append the port number after the domain name and *don't* append it again after the IP. 

If you want to test it from another computer in your local network, change the ip to the local network ip of the machine Caddy is running on.

The `-v` switch is for verbose output. With this, you can see that the SSL certificate is verified.

When you're done testing the tunnel and local access, stop the services with `ctrl-c`. If you are not running the service, enter `docker-compose down`.

### Configure Caddy as a Reverse Proxy

Now, reconfigure Caddy to act as a reverse proxy. On my system, Ollama is running directly on the host. 

As the Ollama API is not protected with an API_KEY, I also added a simple API_KEY check to the Caddyfile. This way, Ollama is protected when it's accessed via the Caddy reverse proxy (and the public `$DOMAIN_NAME`), but still unprotected, when accessed directly via localhost. The API key check protects against unauthenticated use of Ollama from the internet. The unprotected access is necessary for OpenWebUI, since OpenWebUI doesn't support API_KEY authentication for Ollama, yet.

Here is the content of the updated Caddyfile which you can find in `./conf/caddy/Caddyfile`:

```caddy
*.{$DOMAIN_NAME}:443 {
  tls {
    dns cloudflare {$CLOUDFLARE_API_TOKEN}
    resolvers 1.1.1.1
  }

  @ollamaValidApiKey {
    host ollama.{$DOMAIN_NAME}
    header Authorization "Bearer {$OLLAMA_API_KEY}"
  }

  @ollama {
    host ollama.{$DOMAIN_NAME}
  }

  handle @ollamaValidApiKey {
    reverse_proxy host.docker.internal:11434
  }

  handle @ollama {
    header Content-Type application/json
    root * /srv
    rewrite * /401.json
    file_server
  }

  @chat host chat.{$DOMAIN_NAME}
  reverse_proxy @chat open-webui:8080

  log
}
```

These are similarities and differences between the final and the `simple-response` Caddyfile:

- The `tls` directive is the same.
- The `@ollamaValidApiKey` matcher is new, it checks for a valid API_KEY in the `Authorization` header for the Ollama service.
- The `@ollama` matcher is the same.
- The `handle @ollamaValidApiKey` directive is new, it reverse proxies the Ollama service to the local host. The `host.docker.internal` is a special DNS name that resolves to the internal IP address of the host system. It is defined in the docker-compose.yml file for the caddy service (and the open-webui service) so that they can reach the Ollama service which is running directly on the host. You can also deploy Ollama in a container and use the container name as the host, but this is not covered, here.
- The `handle @ollama` directive now responds with a 401 error if no valid API_KEY is provided. Caddy acts as a file server, serving the `401.json` file from the `/srv` directory in all cases. This file replicates the respective error message of the OpenAI API.
- The `@chat` matcher is the same.
- The `reverse_proxy @chat` directive reverse proxies the OpenWebUI service to the local host.
- The `log` directive tells Caddy to log the requests to stdout which then shows up in the docker logs.

Caddy selects the most specific matcher that matches the request. If the client presents a correct API_KEY (which we set using the environment variable `OLLAMA_API_KEY`), the request is reverse proxied to the Ollama service. If the client doesn't present a correct API_KEY, the `@ollama` matcher matches and Caddy responds with a 401 error with the JSON body as defined in `./conf/caddy/401.json`:

```json
{
    "error": { 
        "message": "You didn't provide a valid API key. You need to provide your API key in an Authorization header using Bearer auth (i.e. Authorization: Bearer YOUR_KEY)",
        "type": "invalid_request_error",
        "param": null,
        "code": null
    }
}
```

The final `docker-compose.yml` file looks like this:

```yaml
version: '3'

networks:
  web:
    driver: bridge

services:
  #--- OpenWebUI  ---
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    restart: unless-stopped
    container_name: open-webui
    environment:
      - OLLAMA_API_BASE_URL=http://host.docker.internal:11434/api
      - WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY}
    volumes:
      - ${DATA_DIR-./data}/open-webui:/app/backend/data
    ports:
      - ${OPEN_WEBUI_PORT-3000}:8080
    networks:
      - web
    extra_hosts:
      - "host.docker.internal:host-gateway"
  #--- Caddy ---
  caddy:
    build:
      context: ./images/caddy
      dockerfile: ./Dockerfile
    restart: unless-stopped
    depends_on:
      - open-webui
    environment:
      - CLOUDFLARE_API_TOKEN=${CLOUDFLARE_API_TOKEN}
      - OLLAMA_API_KEY=${OLLAMA_API_KEY}
    volumes:
      - ./conf/caddy/Caddyfile:/etc/caddy/Caddyfile
      - ./conf/caddy/401.json:/srv/401.json
      - ${DATA_DIR-./data}/caddy:/data/caddy
    ports:
      - "443:443"
    networks:
      - web
    extra_hosts:
      - "host.docker.internal:host-gateway"
  #--- Cloudflared ---
  cloudflared:
    image: cloudflare/cloudflared
    restart: unless-stopped
    depends_on:
      - caddy
    volumes:
      - ./conf/cloudflared/config.yaml:/etc/cloudflared/config.yml
      - ${DATA_DIR-./data}/cloudflared/credentials.json:/etc/cloudflared/credentials.json
    command: tunnel --config /etc/cloudflared/config.yml run #--loglevel debug run
    networks:
      - web
```

The `open-webui` service is configured to use the local Ollama service directly with the `OLLAMA_API_BASE_URL`. This way, the OpenWebUI service can access the Ollama service directly without going over the internet and Cloudflare, and without needing to present an API_KEY.

The **ports** section of the `open-webui` service maps the port 8080 of the container to the host system at port 3000 by default. You can configure the port with the `OPEN_WEBUI_PORT` environment variable. With this, , you can also reach the OpenWebUI service from your local machine or your local network directly at `http://localhost:3000/`, for example.

The `extra_hosts` section is needed to resolve the `host.docker.internal` DNS name to the internal IP address of the host system. This is needed because the OpenWebUI service is running in a container and needs to reach the Ollama service which is running directly on the host.

`WEBUI_SECRET_KEY` initializes the OpenWebUI backend with a secret key. This is used to secure the session and the cookies. You can generate a secret key with the following command and save it in an `.env` file (see also the `.env.example` file):

```bash
python -c "import secrets; print(secrets.token_urlsafe())"
```

The `caddy` service is configured to use the final Caddyfile with the reverse proxy configuration. The `CLOUDFLARE_API_TOKEN` and `OLLAMA_API_KEY` are set as environment variables. You can add the `OLLAMA_API_KEY` to the `.env` file with the same python command described above for the `WEBUI_SECRET_KEY`. The `CLOUDFLARE_API_TOKEN` should already be defined there. Finally, the service is also configured to depend on the `open-webui` service.

### Start and Test the Services

Start the services, this time, you can also start them in the background with `docker-compose up -d --build`.

Test from the internet with curl:

```bash
curl -H "Authorization: Bearer $OLLAMA_API_KEY" -v https://ollama.$DOMAIN_NAME/api/generate -d '{
  "model": "llama2",
  "prompt": "Why is the sky blue?"
}'
```

Test from local machine with curl:

```bash
curl -H "Authorization: Bearer $OLLAMA_API_KEY" --resolve "ollama.$DOMAIN_NAME:443:127.0.0.1" -v https://ollama.$DOMAIN_NAME/api/generate -d '{
  "model": "llama2",
  "prompt": "Why is the sky blue?"
}'
```

## How Can I Contribute or Give Feedback?

If you have any questions, suggestions, or improvements, feel free to open an issue or a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
