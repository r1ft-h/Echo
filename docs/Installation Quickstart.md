# Echo Quick‑Start Guide — Bare‑Metal Deployment (Ubuntu 22.04 LTS)

> **Scope** This document walks a Linux administrator through a clean, repeatable installation of **Echo** (vLLM + OpenWebUI) on a physical or virtual Ubuntu Server 22.04 host equipped with an NVIDIA GPU.

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

1. **Clone** the Echo repository to `/opt/echo-src`.
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
sudo git clone https://github.com/<your-org>/Echo.git /opt/echo-src
cd /opt/echo-src/deploy/ubuntu_server
```

### 3.2 Run the Bootstrap Script

```bash
sudo ./setup.sh
```

The script:

* Installs NVIDIA driver 550, Docker Engine & NVIDIA Container Toolkit.
* Creates the directory tree **`/opt/echo`** and seeds it with project files from **`/opt/echo-src`**.
* Configures log rotation and UFW (OpenSSH + OpenWebUI port 8080).

> **Reboot** when the script requests it. Log back in once the host is up.

### 3.3 Confirm Docker/NVIDIA Integration

```bash
docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu22.04 nvidia-smi | head -n 5
```

You should see your GPU listed with the expected driver and CUDA versions.

### 3.4 Directory Layout (Post‑Install)

```
/opt/echo
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
/opt/echo/bin/add-model.sh \
  mistral7b-awq \
  TheBloke/Mistral-7B-Instruct-v0.2-AWQ \
  --quant awq
```

### 3.6 Activate the Model

```bash
/opt/echo/bin/switch-model.sh mistral7b-awq
```

This refreshes the **`current_model`** symlink and restarts the `vllm-server` container.

### 3.7 Launch the Services (if not already running)

```bash
cd /opt/echo/compose
docker compose up -d
```

### 3.8 Validation Checks

```bash
# API endpoint
curl http://localhost:8000/v1/models | jq

# Real‑time logs
cd /opt/echo/compose
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

> Authentication is disabled by default. Toggle `WEBUI_AUTH=true` in `/opt/echo/.env` to enable login.

---

## 4 Essential Commands

| Task                   | Command                                                                                                                       |      |         |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ---- | ------- |
| Stop / start the stack | `docker compose -f /opt/echo/compose/docker-compose.yml down && docker compose -f /opt/echo/compose/docker-compose.yml up -d` |      |         |
| View vLLM logs         | `docker compose -f /opt/echo/compose/docker-compose.yml logs -f vllm-server`                                                  |      |         |
| Update Echo source     | `git -C /opt/echo-src pull` then rerun `setup.sh` (idempotent)                                                                |      |         |
| Add a new model        | \`add-model.sh <alias> \<hf\_repo> --quant \<awq                                                                              | gptq | none>\` |
| Switch active model    | `switch-model.sh <alias>`                                                                                                     |      |         |

---

## 5 Next Steps

* Fine‑tune `.env` (port numbers, OpenWebUI auth, model limits).
* Schedule nightly `git pull` to track Echo updates.
* Integrate an enterprise RAG pipeline (vector store + embeddings) when ready.

> **Need Kubernetes?** A separate manifest lives under `/opt/echo-src/deploy/k8s/`.

---

## 6 Troubleshooting

| Symptom                                                                                | Probable Cause                                                                | Resolution                                                                                                                                                                                                                                                                                  |
| -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`curl: (56) Recv failure: Connection reset by peer`** when querying `localhost:8000` | The vLLM API did not bind to port 8000 or crashed after model load.           | • Run `docker compose -f /opt/echo/compose/docker-compose.yml logs -f vllm-server`.<br>• Ensure `--served-model-name` and `--max-model-len` are present in the compose file.<br>• Verify that the GPU has sufficient memory.<br>• If running under WSL 2, use the tested image tag `0.2.4`. |
| **`ValueError: max seq len … larger than the maximum number of tokens…`**              | The selected model’s context window exceeds the KV‑cache capacity of the GPU. | Reduce `--max-model-len` (e.g. 2048 → 1024) or increase `gpu_memory_utilization` in the compose file.                                                                                                                                                                                       |
| **`nvidia-smi` works on host but fails inside container**                              | NVIDIA Container Toolkit is not registered with Docker.                       | `sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker`                                                                                                                                                                                                       |
| **`permission denied` on `/opt/echo/models`** after manual file deletion               | Folder ownership reverted to `root`.                                          | `sudo chown -R $USER:$USER /opt/echo/models`                                                                                                                                                                                                                                                |
| OpenWebUI not reachable on port 8080                                                   | UFW/firewall rule missing or incorrect.                                       | `sudo ufw allow 8080/tcp` and confirm status with `sudo ufw status numbered`.                                                                                                                                                                                                               |

---

### © 2025 Echo — All rights reserved
