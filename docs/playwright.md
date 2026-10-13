# Playwright browser for AI agents

The `playwright` service runs Microsoft's Playwright MCP server with a headless Chromium. An AI agent such as Claude Code connects to it over MCP (Model Context Protocol) and gets browser tools that open pages, click, type into forms, read the page, and save screenshots. It lets an agent take screenshots of the site and its admin without access to the browser on the host.

## Connecting an agent

`.mcp.json` at the repository root points Claude Code at `http://localhost:24217/mcp`. Claude Code asks once whether to trust the project's MCP servers, and after that the browser tools are available in any session started in this folder. The stack has to be running, because the MCP server is part of it.

Another MCP client uses the same URL with the streamable HTTP transport.

## URLs to open from the browser

The browser shares the gateway container's network, and the gateway listens on the host port numbers as well as its own ports, so the browser opens the same URLs you would on the Mac:

| URL                    | Service    |
| ---------------------- | ---------- |
| http://localhost:24210 | the site   |
| http://localhost:24212 | phpMyAdmin |
| http://localhost:24213 | Mailpit    |
| http://localhost:24214 | Webgrind   |

The site has to be opened at `localhost:24210`, because WordPress, Joomla, and Drupal redirect every request to the URL they were installed with, which is `SITE_URL` in `.env`. An agent can open Mailpit to take screenshots of password reset and notification emails.

The browser can also reach the internet through the gateway's `published` network, so fonts, scripts, and images that a theme loads from a CDN appear in screenshots.

## Screenshots

Screenshots are saved to `./data/screenshots` on the Mac, which is `/screenshots` inside the container. A screenshot taken with a file name is saved under that name, and one taken without a name gets a timestamped name. The server also writes page snapshots (`page-*.yml`) and browser console logs (`console-*.log`) to the same folder. Git ignores everything in `./data/screenshots` except `.gitkeep`.

The viewport is 1440 by 900 pixels. An agent can change it for one session with the `browser_resize` tool.

## Arrows and outlines on screenshots

The `browser_evaluate` tool runs JavaScript in the page, so an agent can add an SVG layer with `position: fixed` and `pointer-events: none` that draws an outline or an arrow at an element's `getBoundingClientRect()` position, and then take the screenshot. The drawing exists only in the browser's copy of the page and is gone after the next navigation, and the playwright container has no access to the site's files. In testing, an outline drawn with an SVG `<rect>` rendered, and an arrowhead drawn with an SVG `<marker>` did not render when the SVG was built with `innerHTML`.

## Logging in to an admin

The agent logs in by filling the login form, the same way a person does, with a username and password you give it in the chat. Each MCP session gets its own browser profile kept in memory (`--isolated`), so cookies and logins are gone when the session ends and nothing is saved to disk.

Any program on your Mac can connect to port 24217 and drive the browser while the stack is running, and the browser keeps whatever admin session an agent logged into until that MCP session ends. The port binds to `127.0.0.1` only, so other machines on the network cannot reach it.

## Settings

The image's entrypoint already passes `--headless`, `--browser chromium`, and `--no-sandbox`. `compose.yml` adds:

- `--host=0.0.0.0` and `--port=8931` so the gateway's published port reaches the server.
- `--allowed-hosts=localhost:24217,127.0.0.1:24217`, so the server rejects requests with any other `Host` header with a 403.
- `--isolated`, explained above.
- `--output-dir=/screenshots` and `working_dir: /screenshots`. The output folder holds screenshots saved without a file name, and screenshots saved with a file name are placed relative to the working directory.
- `--viewport-size=1440x900`.
- `--timeout-action=30000`, which gives a click up to 30 seconds. The default is 5 seconds, and the first load of the WordPress dashboard after logging in took longer than that, so the click failed and the screenshot showed the page before its widgets loaded.

The flags are listed by `docker run --rm mcr.microsoft.com/playwright/mcp:v0.0.83 --help`.

The image's `--no-sandbox` flag turns off Chromium's own sandbox, so the container's `read_only`, `cap_drop: ALL`, and `no-new-privileges` settings are what limit the browser.

Playwright's [Docker page](https://playwright.dev/docs/docker) recommends `--ipc=host` for Chromium and says that without it Chromium can run out of memory and crash. This stack sets `shm_size: 1g` instead of `--ipc=host`, which gives the container 1 GB of its own shared memory.

## Why the browser shares the gateway's network

A container joined with `network_mode: service:gateway` uses the gateway's network stack, so `localhost` inside the playwright container is the gateway and `http://localhost:24210` reaches the site from inside the container. A container on `backend` alone would need a different hostname, which the CMS would redirect away from.

Because the two containers share one network stack, the playwright container cannot publish its own ports. The gateway publishes `127.0.0.1:24217` to port 8931, which the MCP server listens on. When only the gateway is recreated, for example with `docker compose up -d --force-recreate gateway`, the playwright container stays attached to the old gateway's network stack and the MCP server stops answering. Running `docker compose up -d` afterward recreates the playwright container, and the MCP server answers again.

## Updating the image

Between May and September 2026, Microsoft published a new `@playwright/mcp` release every 1 to 5 weeks. Each image includes the Chromium build that its Playwright version uses. The [release notes](https://github.com/microsoft/playwright-mcp/releases) list the changes. The image builds on `node:lts-slim` and does not run `apt-get upgrade`, so a new release only picks up Debian fixes that the Node base image already had on the day it was built.

1. Find the newest stable tag. Skip the `-canary`, `-amd64`, and `-arm64` tags.

    ```sh
    curl -s https://mcr.microsoft.com/v2/playwright/mcp/tags/list
    ```

2. Read the new version's `--help` output and compare it with the flags in `compose.yml`. Change any flag that the new version renamed or removed.

    ```sh
    docker run --rm mcr.microsoft.com/playwright/mcp:<tag> --help
    ```

3. Change the tag in `compose.yml` and in the `--help` command under Settings above, then start the new container.

    ```sh
    docker compose pull playwright
    docker compose up -d playwright
    ```

4. Open http://localhost:24210 through the MCP server and save a screenshot to confirm the browser still works.
5. Scan the image with Snyk. Snyk cannot reach Docker Desktop, so save the image to a tar file and scan that.

    ```sh
    docker save -o "$TMPDIR/playwright-mcp.tar" mcr.microsoft.com/playwright/mcp:<tag>
    snyk container test "docker-archive:$TMPDIR/playwright-mcp.tar"
    ```

6. Add a version to `CHANGELOG.md` that names the new tag.

The scan of v0.0.83 on 2026-10-13 found 41 issues. 20 were in Debian 12 packages and 21 were in the npm copy that ships with Node 24.21.0. Snyk listed a fixed Debian version only for perl-base. Nothing in the container runs perl or npm.
