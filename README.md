# SHAI Lab — **Self‑Hosted AI Inference Stack**

> **One repo → every target**: WSL 2 on Windows, bare‑metal Ubuntu Server, and future k8s rigs.
>
> Production‑grade from day‑1 • GPU‑powered vLLM backend • OpenWebUI front • Audit‑ready admin toolkit.

---

## 🚀 Why this project?

Running a local LLM is easy… until you need:

* **Repeatable installs** across laptops, lab boxes *and* datacentre nodes.
* **Clean separation** between runtime (containers + scripts) and bootstrap (OS‑specific glue).
* **Audit & safety**: every admin action is logged; nothing is done as *root* once the stack is live.
* **Ready for tomorrow**: same tree works whether you scale to multi‑GPU or migrate to Kubernetes.

SHAI Lab is that opinionated skeleton. Clone → run `setup.sh` → `make up` — you’re serving an OpenAI‑compatible endpoint in minutes.

---

## 🗺️ Repo layout (TL;DR)

```text
shai-lab/
├─ bin/               # day‑to‑day admin scripts (add‑model, switch‑model, …)
├─ compose/           # docker‑compose stack  (ports via .env)
├─ deploy/            # one‑shot installers per target OS
│   ├─ wsl/setup.sh   # WSL 2 (Ubuntu 22.04)
│   └─ ubuntu/setup.sh# Bare‑metal Ubuntu Server 22.04
├─ docs/              # operator handbook, architecture notes
├─ inventory/         # (optional) Ansible / Terraform hosts files
├─ models/            # <empty> local HF weights (git‑ignored)
├─ openwebui/data/    # OpenWebUI user DB (git‑ignored)
├─ Makefile           # cross‑platform helper commands
└─ compose/.env.example  # copy to /opt/shai/.env after install
```

> \*\*Heads‑up \*\*: `models/`, `openwebui/data/`, `logs/`, and the real `.env` are excluded by `.gitignore`.

---

## 🏁 Quick start

### Windows 10/11 • WSL 2

```powershell
# PowerShell
wsl --install -d Ubuntu-22.04   # if not yet enabled
wsl --shutdown                  # ensure systemd flag is read later
```

```bash
# inside WSL (Ubuntu 22.04 LTS)
git clone https://github.com/your-org/shai-lab.git
cd shai-lab/deploy/wsl
sudo ./setup.sh          # installs Docker + NVIDIA toolkit + /opt/shai tree
exit                      # logout so group docker is applied
```

```powershell
wsl                       # relaunch WSL shell
```

```bash
cd ~/shai-lab             # repo root
cp compose/.env.example compose/.env
make up                   # pull images + start stack
```

Open [http://localhost:8080](http://localhost:8080) → you’re chatting with your GPU.

### Bare‑metal Ubuntu Server 22.04

```bash
ssh user@server
sudo apt update && sudo apt install git -y
git clone https://github.com/your-org/shai-lab.git
cd shai-lab/deploy/ubuntu
sudo ./setup.sh
logout && login again     # docker group refresh
cd ~/shai-lab && cp compose/.env.example compose/.env && make up
```

---

## 🛠️ Daily operations

| Task             | Command                                                                             |
| ---------------- | ----------------------------------------------------------------------------------- |
| Download a model | `bin/add-model.sh mistral7b-awq mistralai/Mistral‑7B‑Instruct‑v0.2‑AWQ --quant awq` |
| Activate model   | `bin/switch-model.sh mistral7b-awq`                                                 |
| See logs         | `tail -f /opt/shai/logs/bin-actions.log`                                            |
| Stop stack       | `make down`                                                                         |
| Update images    | `make update-all`                                                                   |

Full script reference ▶️ `docs/Shai Lab Scripts Handbook.md`.

---

## 🔐 Security highlights

* **No root** after initial install — scripts run under your user in the `docker` group.
* **All actions audited** to `/opt/shai/logs/bin-actions.log` (weekly rotation ×4).
* **OpenWebUI auth toggle** planned (`bin/enable-auth.sh`).

---

## 🧱 Road‑map

* [x] WSL 2 + Ubuntu install scripts
* [x] Model download/switch helpers
* [ ] Service status & update helpers (`status.sh`, `update-all.sh`)
* [ ] Prometheus / Grafana exporter bundle
* [ ] K8s manifests (Helm chart) in `deploy/k8s/`

> Have a feature in mind? PRs welcome — see **CONTRIBUTING.md** soon.

---

## 💬 Support & community

* Issues / feature requests → GitHub **Issues** tab.
* Security concerns → security\@your‑org.example.

---

## 📜 License

MIT — do whatever you want, just keep the copyright.