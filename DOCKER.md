# Running Hercules with Docker

This guide covers how to build and run Hercules using Docker Compose.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (v20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)
- Git (to clone the repository)

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/HerculesWS/Hercules.git
cd Hercules
```

### 2. Configure environment variables

```bash
cp .env.example .env
```

Open `.env` and adjust the values for your setup:

```env
# Database credentials — change these from defaults
MYSQL_ROOT_PASSWORD=rootpassword
MYSQL_PASSWORD=hercules

# Public-facing IP of your server
# Use 127.0.0.1 for local testing only
# Set to your machine's LAN/public IP if connecting from a game client
CHAR_IP=127.0.0.1
MAP_IP=127.0.0.1
API_IP=127.0.0.1
```

### 3. Build and start all servers

```bash
docker compose up -d
```

This will:
1. Build the Hercules image from source (compiles C code inside Docker)
2. Start MariaDB and wait for it to be healthy
3. Start login-server, then char-server, then map-server and api-server

> **Note:** The first build takes a few minutes as it compiles the entire codebase.

### 4. Verify everything is running

```bash
docker compose ps
```

All services should show as `running (healthy)`.

```bash
docker compose logs -f
```

Press `Ctrl+C` to stop following logs.

---

## Services and Ports

| Service        | Default Port | Description                        |
|----------------|--------------|------------------------------------|
| `mysql`        | —            | MariaDB 11 database (internal only)|
| `login-server` | 6900         | Account authentication             |
| `char-server`  | 6121         | Character and guild management     |
| `map-server`   | 5121         | Game world, NPCs, combat           |
| `api-server`   | 7121         | REST API                           |

Startup order: `mysql` → `login-server` → `char-server` → `map-server` / `api-server`

---

## Connecting a Game Client

Point your game client's `clientinfo.xml` (or equivalent) to your server's IP:

- **Login server:** `your.server.ip:6900`

Make sure `CHAR_IP` and `MAP_IP` in `.env` are set to the same IP your client can reach.

For local testing on the same machine, `127.0.0.1` works. For LAN play, use your machine's local IP (e.g. `192.168.1.x`). For internet access, use your public IP and ensure the ports are forwarded.

---

## Persistent Data

| Data             | Location                        | Notes                              |
|------------------|---------------------------------|------------------------------------|
| Database         | Docker volume `mysql_data`      | Survives container restarts        |
| Save files       | `./save/` (host directory)      | Mounted into map-server            |
| Server logs      | `./log/` (host directory)       | Mounted into map-server            |

---

## Common Commands

**Start servers:**
```bash
docker compose up -d
```

**Stop servers (keep data):**
```bash
docker compose down
```

**Stop servers and wipe database:**
```bash
docker compose down -v
```

**Rebuild after source code changes:**
```bash
docker compose build
docker compose up -d
```

**View logs for a specific server:**
```bash
docker compose logs -f map-server
docker compose logs -f char-server
docker compose logs -f login-server
```

**Open a shell inside a running container:**
```bash
docker compose exec map-server bash
```

**Connect to the database:**
```bash
docker compose exec mysql mariadb -u hercules -phercules hercules
```

---

## Configuration

All server configuration is driven by environment variables in `.env`. The `docker-entrypoint.sh` script generates the appropriate config import files at startup.

### Changing Inter-Server Credentials

The default inter-server credentials (`s1`/`p1`) will trigger a warning in the logs. To change them:

1. Start the servers once with defaults so the database is initialized.
2. Update the `login` table:
   ```sql
   UPDATE login SET userid='newuser', user_pass='newpass' WHERE account_id=1;
   ```
3. Update `.env`:
   ```env
   INTER_USERID=newuser
   INTER_PASSWORD=newpass
   ```
4. Restart the servers:
   ```bash
   docker compose restart
   ```

### Custom Server Ports

Edit the port values in `.env`:
```env
LOGIN_PORT=6900
CHAR_PORT=6121
MAP_PORT=5121
API_PORT=7121
```

---

## Troubleshooting

**Servers fail to start / keep restarting**

Check the logs:
```bash
docker compose logs login-server
docker compose logs char-server
docker compose logs map-server
```

**Map server can't connect to char server**

The map-server waits for char-server to be healthy before starting. If it times out, check that char-server started successfully first.

**Game client can't connect**

- Ensure `CHAR_IP` and `MAP_IP` in `.env` are set to the IP your client can reach (not `127.0.0.1` unless client is on the same machine).
- Ensure ports `6900`, `6121`, and `5121` are open in your firewall.
- Rebuild and restart after changing `.env`: `docker compose up -d`

**Database connection errors**

The login table needs the inter-server account. If you wiped the database volume, it will be re-initialized automatically on next startup via the MariaDB Docker image's init process.

**Starting fresh (wipe everything)**

```bash
docker compose down -v   # removes containers and the mysql_data volume
docker compose up -d     # starts fresh with a clean database
```
