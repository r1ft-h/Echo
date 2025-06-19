# Echo Operations Handbook

> **Audience** Infrastructure & DevOps engineers responsible for day‑to‑day operation, scaling and maintenance of a self‑hosted Echo stack.

---

## 1  Model‑to‑Hardware Sizing Matrix

| Model Class                  | Quantisation    | vRAM Required         | Recommended GPU(s)               | Approx. Throughput (tok/s) | Notes                                             |
| ---------------------------- | --------------- | --------------------- | -------------------------------- | -------------------------- | ------------------------------------------------- |
| **7 B** (e.g. Mistral‑7B)    | 4‑bit <br>8‑bit | **6 GiB**<br>\~12 GiB | RTX 3060 12 GB<br>RTX 3080 10 GB | 15‑25 (single user)        | Safe default for PoC; fits almost any modern GPU. |
| **13 B** (e.g. Llama‑3‑13B)  | 4‑bit           | **11 GiB**            | RTX 3080 Ti 12 GB                | 8‑12                       | Requires context window ≤ 4 k.                    |
| **33 B** (e.g. Mixtral‑8x7B) | 4‑bit           | **22 GiB**            | RTX 4090 24 GB                   | 5‑8                        | Mixture‑of‑Experts; benefits from PCIe 4.0.       |
| **70 B** (e.g. Llama‑3‑70B)  | 4‑bit           | **48 GiB**            | A6000 48 GB or multi‑GPU NVLink  | 2‑5                        | Multi‑GPU parallelism via vLLM tensor‑parallel 2. |

> \*\*Tip \*\*Use the `--gpu-memory-utilization` flag (default 0.9) to fine‑tune KV‑cache allocation if you observe OOM errors.

---

## 2  Lifecycle & Maintenance

### 2.1  Updating Containers

```bash
cd /opt/echo/compose
# Pull newer tags defined in docker‑compose.yml
docker compose pull
# Recreate with zero downtime
docker compose up -d --remove-orphans
```

*Never* use `latest` tags in production; pin to a tested version (e.g. `vllm-openai:0.3.2.post1`).

### 2.2  Updating Echo Scripts & Docs

```bash
cd /opt/echo-src
git pull
sudo rsync -a --exclude='.git' /opt/echo-src/ /opt/echo/
# restart if bin/ or compose/ changed
```

### 2.3  GPU Driver & CUDA

* **Bare‑metal:** install `nvidia-driver-550` from the graphics‑drivers PPA.<br>- **WSL 2:** keep Windows GPU driver ≥ 560.xx to match CUDA 12.6.

Check compatibility matrix in `/opt/echo/doc/cuda_matrix.md` before upgrading.

---

## 3  Advanced Troubleshooting

| Category               | Diagnostic Command                              | Actionable Fix                                                                                   |
| ---------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| **High GPU memory**    | `nvidia-smi` → Mem > 90 %                       | Lower `--gpu-memory-utilization` to 0.8 or cut `--max-model-len`.                                |
| **Slow throughput**    | `docker stats` shows CPU > 300 %                | Add `--tensor-parallel-size 2` on dual‑GPU or enable speculative decoding.                       |
| **OOM during compile** | `CUDA out of memory while capturing cudagraphs` | Add `--enforce-eager` flag or reduce `gpu_memory_utilization`.                                   |
| **Tokenizer stall**    | vLLM log stuck at `Initializing tokenizer pool` | Set `TOKENIZER_POOL_SIZE=0` (fallback to single‑thread).                                         |
| **Healthcheck fail**   | API `/v1/models` returns 500                    | Check model path, verify symlink `/opt/echo/vllm/current_model` and run `switch-model.sh` again. |

---

## 4  Backup & Disaster Recovery

| Component        | Backup Target                   | Strategy                                |
| ---------------- | ------------------------------- | --------------------------------------- |
| LLM Models       | `/opt/echo/models/`             | Snapshots or `rsync` to object storage. |
| User Data        | `/opt/echo/openwebui/data/`     | Nightly `tar.gz` → off‑site.            |
| Config & Scripts | `/opt/echo/` (excluding models) | Git‑mirror to private repo.             |

> \*\*Note \*\*Models can be re‑downloaded but may be gated; keep local copies for air‑gapped recovery.

---

## 5  Routine Operational Checklist

| Frequency | Task                                                                      |
| --------- | ------------------------------------------------------------------------- |
| Daily     | Verify `docker ps`, inspect error logs.                                   |
| Weekly    | Pull security patches (`apt-get update && apt-get upgrade`); rotate logs. |
| Monthly   | Refresh container images (`docker compose pull`).                         |
| Quarterly | GPU driver & CUDA compatibility review.                                   |

---

## 6  Contact & Escalation

* **Primary Ops:** ops@prizm-security.com<br>- **Vendor Support:** NVIDIA Enterprise, OpenWebUI community.

> For critical production incidents, escalate to the Echo on‑call Mattermost channel `#echo-ops`.

---

© 2025 Echo — Internal Use Only
