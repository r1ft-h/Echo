# SHAI Quick‑Start Guide — Bare‑Metal Deployment (Ubuntu 22.04 LTS)

> **Scope** This document walks a Linux administrator through a clean, repeatable installation of **SHAI** (vLLM + OpenWebUI) on a physical or virtual Ubuntu Server 22.04 host equipped with an NVIDIA GPU.

---

## 1 System Requirements

| Item                 | Minimum                                             | Recommended                         |
| -------------------- | --------------------------------------------------- | ----------------------------------- |
| **Operating system** | Ubuntu Server 22.04 LTS (64‑bit)                    | Latest HWE kernel applied           |
| **GPU / driver**     | NVIDIA Ampere or newer, CUDA ≥ 12.8                 | RTX 4090 (24 GiB) or A6000 (48 GiB) |
| **Privileges**       | `sudo` access                                       | —                                   |
| **Network**          | Internet access to GitHub, Docker Hub, Hugging Face | Static public IP or DNS entry       |

> **Note** On air‑gapped systems, mirror the container images and model artifacts first.

---

## 2 High‑Level Workflow

1. **Clone** the SHAI repository to `/opt/shai-src`.
2. **Execute** the bootstrap script (`setup.sh`).
3. **Reboot / re‑login** if prompted (GPU driver & Docker group).
4. **Add** an LLM with `add-model.sh`.
5. **Activate** the model with `switch-model.sh` (automatically restarts vLLM).
6. **Verify** the OpenAI‑compatible API and launch OpenWebUI.

A fully functional stack is typically online in **≤ 15 min** on a 1 Gbps link.

---

## 3 Detailed Procedure

### 3.1 Obtain the Source

```bash
sudo apt update && sudo apt install -y git
sudo git clone https://github.com/<your-org>/SHAI.git /opt/shai-src
cd /opt/shai-src/deploy/ubuntu_server
```

### 3.2 Run the Bootstrap Script

```bash
sudo ./setup.sh
```

The script:

* Installs NVIDIA driver 550, Docker Engine & NVIDIA Container Toolkit.
* Creates the directory tree **`/opt/shai`** and seeds it with project files from **`/opt/shai-src`**.
* Configures log rotation and UFW (OpenSSH + OpenWebUI port 8080).

> **Reboot** when the script requests it. Log back in once the host is up.

### 3.3 Confirm Docker/NVIDIA Integration

```bash
docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu22.04 nvidia-smi | head -n 5
```

You should see your GPU listed with the expected driver and CUDA versions.

### 3.4 Directory Layout (Post‑Install)

```
/opt/shai
├── bin/                # operational scripts
├── compose/            # docker‑compose YAML files
├── models/             # downloaded LLMs (one sub‑dir per model)
│   └── mistral7b-awq/
├── vllm/current_model → ../models/mistral7b-awq
├── openwebui/data/     # OpenWebUI state (users, settings, uploads)
├── logs/               # log files (rotated weekly)
└── .env                # runtime configuration (ports, auth, etc.)
```

### 3.5 Download a Model

```bash
/opt/shai/bin/add-model.sh \
  mistral7b-awq \
  TheBloke/Mistral-7B-Instruct-v0.2-AWQ \
  --quant awq
```

### 3.6 Activate the Model

```bash
/opt/shai/bin/switch-model.sh mistral7b-awq
```

This refreshes the **`current_model`** symlink and restarts the `vllm-server` container.

### 3.7 Launch the Services (if not already running)

```bash
cd /opt/shai/compose
docker compose up -d
```

### 3.8 Validation Checks

```bash
# API endpoint
curl http://localhost:8000/v1/models | jq

# Real‑time logs
cd /opt/shai/compose
docker compose logs -f vllm-server
```

An example response:

```json
{"object":"list","data":[{"id":"mistral7b-awq", ... }]}
```

### 3.9 Access OpenWebUI

Open a browser to:

```
http://<server‑ip>:8080
```

> Authentication is disabled by default. Toggle `WEBUI_AUTH=true` in `/opt/shai/.env` to enable login.

---

## 4 Essential Commands

| Task                   | Command                                                                                                                       |      |         |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ---- | ------- |
| Stop / start the stack | `docker compose -f /opt/shai/compose/docker-compose.yml down && docker compose -f /opt/shai/compose/docker-compose.yml up -d` |      |         |
| View vLLM logs         | `docker compose -f /opt/shai/compose/docker-compose.yml logs -f vllm-server`                                                  |      |         |
| Update SHAI source     | `git -C /opt/shai-src pull` then rerun `setup.sh` (idempotent)                                                                |      |         |
| Add a new model        | \`add-model.sh <alias> \<hf\_repo> --quant \<awq                                                                              | gptq | none>\` |
| Switch active model    | `switch-model.sh <alias>`                                                                                                     |      |         |

---

## 5 Next Steps

* Fine‑tune `.env` (port numbers, OpenWebUI auth, model limits).
* Schedule nightly `git pull` to track SHAI updates.
* Integrate an enterprise RAG pipeline (vector store + embeddings) when ready.

> **Need Kubernetes?** A separate manifest lives under `/opt/shai-src/deploy/k8s/`.

---

### © 2025 SH.AI — All rights reserved
