# SHAI Stack — **Operations Handbook**

This handbook provides a complete, step‑by‑step reference for installing, operating and maintaining the SHAI self‑hosted AI stack on either **WSL 2** (Windows 10/11) or **Ubuntu Server 22.04**.

> **Objective** — Deliver an OpenAI‑compatible API and a Web interface backed by your own GPU, under your control, with production‑ready practices from day one.

---

## 1 · Stack overview

| Layer             | Technology                        | Purpose                                                                  |
| ----------------- | --------------------------------- | ------------------------------------------------------------------------ |
| **vLLM**          | CUDA‑accelerated inference engine | Serves Hugging Face models through a high‑performance API.               |
| **OpenWebUI**     | React + FastAPI                   | Web chat interface, file uploads, conversation history.                  |
| **Docker**        | OCI container runtime             | Ensures reproducible, isolated deployment.                               |
| **Admin scripts** | `bin/*.sh`                        | One‑command helpers: model download / switch, service restarts, updates. |

All runtime data resides under `/opt/shai`. Logs are rotated weekly and retained for four weeks.

---

## 2 · Prerequisites

### Hardware

* **NVIDIA GPU** — 12 GB VRAM minimum (RTX 3060 or higher).
* 16 GB + system RAM.
* 50 GB free storage (models and containers).

### Software

| Environment             | Notes                                                                                           |
| ----------------------- | ----------------------------------------------------------------------------------------------- |
| **WSL 2**               | Windows 10/11 with Ubuntu 22.04 distribution and the latest NVIDIA driver **with WSL support**. |
| **Ubuntu Server 22.04** | Clean installation recommended; outbound Internet required during bootstrap.                    |

---

## 3 · Repository structure

```text
shai-stack/
 ├─ bin/                   # operational scripts
 ├─ compose/               # docker‑compose.yml + .env template
 ├─ deploy/                # one‑time installers per target OS
 │   ├─ wsl/setup.sh
 │   └─ ubuntu_server/setup.sh
 ├─ docs/                  # handbooks, architecture notes
 ├─ models/                # Hugging Face weights (git‑ignored)
 └─ openwebui/data/        # UI data (git‑ignored)
```

All commands below assume execution from the repository root.

---

## 4 · Installation

### 4.1 · WSL 2

1. **Enable systemd** (one‑time):

   ```powershell
   wsl --shutdown
   ```

   In Ubuntu:

   ```ini
   # /etc/wsl.conf
   [boot]
   systemd=true
   ```
2. **Bootstrap**:

   ```bash
   cd deploy/wsl
   sudo ./setup.sh
   exit              # re‑enter shell to refresh docker group membership
   ```
3. **Re‑open** the WSL shell.

### 4.2 · Ubuntu Server

```bash
cd deploy/ubuntu_server
sudo ./setup.sh     # reboot if the script requests it
```

---

## 5 · Starting the stack

```bash
cp compose/.env.example compose/.env   # first time only
make up                                 # pull images and launch services
```

* **Web UI** — \<http\://\<host‑ip>:8080>
* **OpenAI‑compatible API** — `POST http://<host‑ip>:8000/v1/chat/completions`

If 8080/TCP is blocked, open it in the Windows Firewall (WSL) or UFW (Ubuntu Server).

---

## 6 · Model management

### 6.1 · Download

```bash
bin/add-model.sh mistral7b-awq \
  mistralai/Mistral-7B-Instruct-v0.2-AWQ --quant awq
```

*Creates `/opt/shai/models/mistral7b-awq`, downloads the model, logs the action, and adjusts `MODEL_QUANT` in `.env` if specified.*

### 6.2 · Activate

```bash
bin/switch-model.sh mistral7b-awq
```

*Updates the `current_model` symlink and restarts the vLLM container.*

| Path                           | Description                         |
| ------------------------------ | ----------------------------------- |
| `/opt/shai/models/<alias>`     | Directory containing model weights. |
| `/opt/shai/vllm/current_model` | Symlink to the active alias.        |

---

## 7 · Daily operations

| Task                   | Command             |
| ---------------------- | ------------------- |
| View service table     | `make status`       |
| Tail real‑time logs    | `make logs`         |
| Restart vLLM only      | `make restart-vllm` |
| Pull images & redeploy | `make update-all`   |

All available targets: `make help`.

---

## 8 · Logging and troubleshooting

| Log                              | Contents                               |
| -------------------------------- | -------------------------------------- |
| `/opt/shai/logs/bin-actions.log` | Audit trail (user, timestamp, action). |
| `docker logs vllm-server`        | Model loading, CUDA errors.            |
| `docker logs openwebui`          | Front‑end events and errors.           |

Typical issues

| Symptom                      | Resolution                                                 |
| ---------------------------- | ---------------------------------------------------------- |
| **CUDA OOM**                 | Use a 4‑bit AWQ variant or free GPU VRAM.                  |
| **nvidia‑smi missing (WSL)** | Reinstall the latest NVIDIA driver with WSL support.       |
| **8080 unreachable**         | Open the port on the host firewall or change it in `.env`. |

---

## 9 · Updating

```bash
make update-all      # update containers
bin/add-model.sh …   # optional: pull newer model release
```

Persisted data (models, UI) remains intact across updates.

---

## 10 · Backup guidelines

| Asset         | Location                    | Strategy                                            |
| ------------- | --------------------------- | --------------------------------------------------- |
| Models        | `/opt/shai/models/`         | Rsync or snapshot; treat as read‑only.              |
| UI data       | `/opt/shai/openwebui/data/` | Daily snapshot if conversation history is critical. |
| Configuration | Git repository              | Push to remote Git hosting.                         |

---

## 11 · Extension roadmap

* **Multi‑GPU** — Duplicate `vllm-server` services (one per GPU).
* **Retrieval‑Augmented Generation** — Integrate Qdrant/Chroma + retriever container.
* **Monitoring** — Prometheus + NVIDIA DCGM exporter for VRAM metrics.

---

## 12 · Glossary

| Term           | Description                                                      |
| -------------- | ---------------------------------------------------------------- |
| **AWQ**        | 4‑bit activation‑aware quantised weights.                        |
| **GPTQ**       | 4‑bit post‑training weight quantisation.                         |
| **HF repo ID** | Reference on huggingface.co (e.g. `meta-llama/Llama-2-7b-hf`).   |
| **Symlink**    | Filesystem pointer; enables model hot‑swap without config edits. |

---

© 2025 PRIZM — All rights reserved.
