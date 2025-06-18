```
███████╗ ██████╗██╗  ██╗ ██████╗ 
██╔════╝██╔════╝██║  ██║██╔═══██╗
█████╗  ██║     ███████║██║   ██║
██╔══╝  ██║     ██╔══██║██║   ██║
███████╗╚██████╗██║  ██║╚██████╔╝
╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ 
```

# SHAI  —  Self‑Hosted AI Stack

**SHAI** delivers a production‑ready, GPU‑accelerated inference stack combining:

* **vLLM** (OpenAI‑compatible API)
* **OpenWebUI** (chat front‑end)
* A curated library of scripts to manage local models, updates and logging

Designed for consulting firms specialising in **Identity & Access Management (IAM)** but adaptable to any domain.

---

## ✨ Key Goals

1. **Data privacy** — run inference fully on‑prem.
2. **Cost control** — one‑off hardware purchase beats SaaS token billing.
3. **Modularity** — WSL 2, bare‑metal, or Kubernetes; same workflow.
4. **Zero‑to‑Chat** in ≤ 15 min with automated installers.

---

## Repo Layout

```
SHAI/
├─ bin/                   # Shell helpers (add‑model, switch‑model, etc.)
├─ compose/               # Docker Compose files per target
│  ├─ docker-compose.yml  # WSL flavour
│  └─ docker-compose-baremetal.yml
├─ deploy/
│  ├─ ubuntu_server/      # Bare‑metal bootstrap
│  ├─ wsl/                # WSL 2 bootstrap
│  └─ k8s/                # Helm/Kustomize manifests (WIP)
├─ doc/
│  ├─ quickstart-baremetal.md
│  ├─ shai-operations-handbook.md
│  └─ openwebui-admin-guide.md
└─ models/                # (git‑ignored) local model cache
```

> **Tip:** Model payloads live outside Git in `/opt/shai/models/` once deployed.

---

## 📚 Documentation Map

| Document                            | Description                                                      |
| ----------------------------------- | ---------------------------------------------------------------- |
| **doc/quickstart-baremetal.md**     | End‑to‑end install on Ubuntu Server with NVIDIA GPU.             |
| **doc/shai-operations-handbook.md** | Hardware sizing, lifecycle management, advanced troubleshooting. |
| **doc/openwebui-admin-guide.md**    | Branding, authentication, feature flags for the front‑end.       |

For WSL 2 or Kubernetes, see the respective README inside each `deploy/` sub‑folder.

---

## 🚀 Getting Started (Bare‑Metal TL;DR)

```bash
# 1. Clone
sudo git clone https://github.com/<your-org>/SHAI.git /opt/shai-src

# 2. Bootstrap system
cd /opt/shai-src/deploy/ubuntu_server && sudo ./setup.sh
# Reboot if prompted, then re‑login

# 3. Load a model
/opt/shai/bin/add-model.sh mistral7b-awq \
  TheBloke/Mistral-7B-Instruct-v0.2-AWQ --quant awq
/opt/shai/bin/switch-model.sh mistral7b-awq

# 4. Chat away
open http://<server-ip>:8080
```

---

## 🤝 Contributing

PRs and issue reports are welcome. Please review `CONTRIBUTING.md` and open an issue before significant changes.

---

© 2025 SH.AI — MIT License (see `LICENSE`)
