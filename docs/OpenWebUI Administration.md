# OpenWebUI Administration & Customisation Guide (SHAI Edition)

> **Scope** This document explains how to operate, secure and customise the OpenWebUI front‑end shipped with SHAI. It targets platform administrators who already deployed the base stack.

---

## 1 Container Overview

| Service       | Image Tag                            | Default Port | Purpose                                                          |
| ------------- | ------------------------------------ | ------------ | ---------------------------------------------------------------- |
| **openwebui** | `ghcr.io/open-webui/open-webui:main` | `8080`       | Web front‑end exposing ChatGPT‑style UI and multi‑model routing. |

The container is defined in `/opt/shai/compose/docker-compose.yml` and is network‑isolated on the `shai` bridge.

---

## 2 Core Environment Variables

| Variable                   | Default                      | Description                                                   |
| -------------------------- | ---------------------------- | ------------------------------------------------------------- |
| `OPENAI_API_BASE_URL`      | `http://vllm-server:8000/v1` | Endpoint for OpenAI‑compatible backend (vLLM).                |
| `WEBUI_AUTH`               | `false`                      | When `true`, enables account‑based login (SQLite user store). |
| `WEBUI_THEME`              | `light`                      | Can be `light`, `dark`, `auto`.                               |
| `WEBUI_TITLE`              | `SHAI Chat`                  | Browser title & header branding.                              |
| `WEBUI_MAX_TOKENS`         | `1024`                       | Hard cap exposed in UI drop‑down.                             |
| `WEBUI_RATE_LIMIT_PER_MIN` | `0` (disabled)               | Max requests per user/min (0 = unlimited).                    |

Edit `/opt/shai/.env`, then run `docker compose up -d` to apply.

---

## 3 Branding & Theme Customisation

1. **Logo:** Mount a PNG into `/opt/shai/openwebui/data/static/logo.png`.
2. **Favicon:** Replace `/opt/shai/openwebui/data/static/favicon.ico`.
3. **Colours:** Create `/opt/shai/openwebui/data/custom.css` and override CSS vars:

   ```css
   :root {
     --primary-500: #00a389; /* corporate green */
   }
   ```
4. **Activate:** Rebuild container or volume‑mount the `data/` folder (already done in compose YAML). No further steps required.

---

## 4 User & Role Management

When `WEBUI_AUTH=true`, OpenWebUI stores users in `data/database.sqlite`.

### 4.1 Create First Admin User

```bash
docker compose -f /opt/shai/compose/docker-compose.yml exec openwebui \
  bash -c "python manage.py create-admin --username admin --password 'S3cureP@ss!'"
```

The account receives the **ADMIN** role and can invite others from the UI.

### 4.2 Role Matrix

| Role  | Capabilities                                                |
| ----- | ----------------------------------------------------------- |
| USER  | chat, view history, upload files                            |
| ADMIN | all USER rights + invite/disable users, set global settings |

Custom roles are not yet supported (upstream roadmap Q4 2025).

---

## 5 Feature Flags

| Feature            | Toggle                          | Description                                  |
| ------------------ | ------------------------------- | -------------------------------------------- |
| **File Upload**    | `WEBUI_ENABLE_UPLOAD=true`      | Enables PDF/Text/Code uploads for context.   |
| **Rate Limiting**  | `WEBUI_RATE_LIMIT_PER_MIN`      | Set to e.g. `30` to cap abuse.               |
| **System Prompts** | UI > *Settings → System Prompt* | Force a default system prompt for all chats. |
| **Plugins**        | `WEBUI_ENABLE_PLUGINS=true`     | Allow experimental community plugins.        |

Toggle in `.env` or via the admin panel (persists in DB).

---

## 6 Updating OpenWebUI

```bash
cd /opt/shai/compose
docker compose pull openwebui
docker compose up -d openwebui
```

Always read the release notes; breaking changes occasionally require DB migrations (`python manage.py migrate`).

---

## 7 Advanced Troubleshooting

| Symptom                     | Check                                    | Remediation                                                             |
| --------------------------- | ---------------------------------------- | ----------------------------------------------------------------------- |
| 404 on `/api/chat`          | Container couldn’t reach vLLM backend.   | Verify `OPENAI_API_BASE_URL`, check `vllm-server` health.               |
| Login loop / cookie issues  | Browser console shows `SameSite` errors. | Set `WEBUI_COOKIE_SAMESITE=lax` in `.env`.                              |
| High latency (>5 s)         | `docker stats` shows CPU saturated.      | Enable batching in vLLM, scale GPU, reduce `max_model_len`.             |
| `database is locked` errors | SQLite file on slow NFS/FS.              | Move `data/` to local SSD or migrate to PostgreSQL (upstream optional). |

---

### © 2025 SH.AI — Internal Use Only
