# LeoMultiCloud

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/Cloud-AWS-FF9900)](https://aws.amazon.com/)
[![Azure](https://img.shields.io/badge/Cloud-Azure-0078D4)](https://azure.microsoft.com/)

**Design and Evaluation of a Multi-Cloud Disaster Recovery Architecture**

B.Sc. Cloud Architect Project — TU Dublin, Programme H4036, Academic Year 2026  
Author: Leonardo Bagno

---

## Overview

This project designs, implements, and empirically evaluates a multi-cloud disaster recovery architecture deployed across AWS (primary) and Azure (secondary). Automated DNS-based failover is managed by Amazon Route 53, with health checks monitoring a lightweight Flask weather application running under Nginx and Gunicorn on both clouds.

The principal academic contribution is the **empirical separation of Route 53 health-check detection time from DNS TTL propagation time** — a decomposition not present in the reviewed literature (Li et al., 2025; Tong, 2023; Vironica et al., 2025; Suyatno, Ferdiana and Widyawan, 2025).

---

## Key Findings

| Metric                                    | Result                                           |
| ----------------------------------------- | ------------------------------------------------ |
| Mean failover RTO (all TTL configs, n=9)  | **48.0 s**                                       |
| RTO at TTL=60s (mean ± SD)                | 46.3 s ± 0.6 s                                   |
| RTO at TTL=120s (mean ± SD)               | 45.3 s ± 2.9 s                                   |
| RTO at TTL=300s (mean ± SD)               | 52.3 s ± 7.6 s                                   |
| Failback RTO at TTL=60s (mean ± SD)       | 35.3 s ± 3.1 s                                   |
| Recovery Point Objective (RPO)            | **0 seconds** (stateless workload)               |
| Route 53 detection time (TTL-independent) | ~48 s across all configurations                  |
| Post-failover oscillation at TTL=300s     | Cloudflare >325 s · Google DNS stabilised faster |
| Total infrastructure cost                 | **< €5** across all three iterations             |

> **Core finding:** Route 53 health-check detection time (~48 s) is governed by the internal polling and quorum logic, not by the TTL advertised to external resolvers. TTL controls post-failover propagation and resolver caching behaviour, not the detection phase.

---

## Architecture

```
                        ┌─────────────────────────────────┐
                        │        Amazon Route 53           │
                        │  Health checks every 10s         │
                        │  Failover routing policy         │
                        │  3 consecutive failures → flip   │
                        └──────────┬──────────────┬────────┘
                                   │              │
                    ┌──────────────▼──┐     ┌─────▼──────────────┐
                    │   AWS (Primary) │     │  Azure (Secondary)  │
                    │   eu-west-1     │     │  West Europe        │
                    │                 │     │                      │
                    │  EC2 (t3.micro) │     │  VM (D2as_v7 Gen2)  │
                    │  Elastic IP     │     │  Static Public IP    │
                    │  VPC            │     │  VNet                │
                    │                 │     │                      │
                    │  Nginx → 80     │     │  Nginx → 80          │
                    │  Gunicorn → 5000│     │  Gunicorn → 5000     │
                    │  Flask (systemd)│     │  Flask (systemd)     │
                    │  /health        │     │  /health             │
                    └─────────────────┘     └──────────────────────┘
```

**Active-passive** model. Terraform provisions both environments from a single codebase. No Docker — the application runs natively on the VM via systemd to eliminate container startup noise from RTO measurements.

---

## Repository Structure

```
leomulticloud/
├── terraform/
│   ├── providers.tf          # AWS + Azure provider configuration
│   ├── variables.tf          # dns_ttl + input variables
│   ├── aws_compute.tf        # EC2 instance, security group, key pair, Elastic IP
│   ├── azure_compute.tf      # Virtual machine, networking, Public IP
│   ├── dns.tf                # Route 53 health checks + failover records
│   ├── outputs.tf            # Public IPs, application endpoints
│   ├── cloud-init.yaml       # Automated VM provisioning (both clouds)
│   └── terraform.tfvars.example
├── flask-weather-app/
│   └── app.py                # Flask application with /health endpoint
├── tests/
│   ├── measure_rto_dns.sh    # RTO measurement script (1s poll, CSV output)
│   └── results/              # Timestamped CSV results from all experiment runs
├── aws/                      # Legacy AWS-only configs (Iteration 1 reference)
├── Makefile                  # Standardised operations (init/plan/apply/health/experiment/destroy)
├── ACADEMIC_JOURNEY.md       # Iteration-by-iteration development log
├── LICENSE
└── README.md
```

---

## Technology Stack

| Category          | Technology                         | Purpose                                        |
| ----------------- | ---------------------------------- | ---------------------------------------------- |
| IaC               | Terraform                          | Multi-cloud infrastructure provisioning        |
| Cloud (Primary)   | AWS EC2, VPC, Elastic IP, Route 53 | Primary environment + DNS failover             |
| Cloud (Secondary) | Azure VM, VNet, Public IP          | Secondary environment                          |
| Application       | Python 3 / Flask                   | Lightweight stateless weather app              |
| Web stack         | Nginx + Gunicorn + systemd         | Reverse proxy, WSGI server, service management |
| Provisioning      | cloud-init                         | Automated first-boot configuration             |
| Measurement       | Bash / dig / CSV                   | RTO data collection (1s polling resolution)    |
| API               | OpenWeatherMap (free tier)         | Weather data source                            |
| Version control   | Git / GitHub                       | Source and IaC versioning                      |

---

## Reproducing the Experiments

### Prerequisites

- AWS account (free tier sufficient) with programmatic access configured
- Azure account with an active subscription (`az login`)
- Terraform ≥ 1.5
- Python 3.x
- An SSH key pair

### 1. Clone and initialise

```bash
git clone https://github.com/leobagno-labs/leomulticloud.git
cd leomulticloud
make init
```

### 2. Configure variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your AWS credentials, Azure subscription,
# SSH public key, OpenWeatherMap API key, and desired dns_ttl
```

### 3. Deploy both clouds

```bash
make apply
# Provisions AWS VPC + EC2 and Azure VNet + VM in ~10 minutes
# cloud-init automatically installs and starts the Flask stack on both
```

### 4. Verify deployment

```bash
make health
# Both /health endpoints should return HTTP 200 with cloud_provider field
```

### 5. Run a failover experiment

```bash
# In one terminal — start the measurement script
DNS_TTL=60 bash tests/measure_rto_dns.sh

# Press ENTER, then immediately in a second terminal:
ssh ubuntu@<AWS_IP> "sudo systemctl stop flask-weather-app"

# The script polls DNS every 1s and records elapsed time to CSV
# Failover detected when resolved IP switches from AWS Elastic IP to Azure Public IP
```

### 6. Run a failback experiment

After failover stabilises, restart the AWS service:

```bash
ssh ubuntu@<AWS_IP> "sudo systemctl start flask-weather-app"
# The same measurement script continues polling and records failback RTO
```

### 7. Multi-resolver comparison (TTL=300s)

```bash
# Google Public DNS
DNS_TTL=300 bash tests/measure_rto_dns.sh  # uses 8.8.8.8 by default

# Cloudflare — edit the dig command in measure_rto_dns.sh to @1.1.1.1
DNS_TTL=300 bash tests/measure_rto_dns.sh
```

### 8. Clean up

```bash
make destroy
# Destroys all AWS and Azure resources to avoid ongoing charges
```

> **Expected total cost:** < €5 for all three iterations combined, using AWS free tier and Azure for Students credits.

---

## Iteration History

| Tag    | Description                                                                                                             |
| ------ | ----------------------------------------------------------------------------------------------------------------------- |
| `v1.0` | Iteration 1 — Both cloud environments deployed and verified; DNS configured but not yet tested                          |
| `v2.0` | Iteration 2 — Single-run failover experiments at TTL=60s, 120s, 300s; domain registered; RPO validated                  |
| `v3.0` | Iteration 3 — Three repeated runs per TTL; 1s poll resolution; multi-resolver comparison at TTL=300s; failback measured |

---

## AI Use Declaration

In accordance with TU Dublin's Guidelines on the Responsible Use of Generative AI (AIAS Level 3 — AI Collaboration), Anthropic's Claude assisted with Terraform configuration, debugging of the cloud-init `$$` escape issue, and the `measure_rto_dns.sh` script. All AI-generated outputs were evaluated, modified, and tested before use. The experimental design, deployment, debugging, architectural decisions, literature review, and empirical analysis are the author's own work.

---

## Citation

If you use this work, please cite:

```bibtex
@misc{bagno2026leomulticloud,
  author       = {Bagno, Leonardo},
  title        = {Design and Evaluation of a Multi-Cloud Disaster Recovery Architecture},
  year         = {2026},
  institution  = {Technological University Dublin},
  note         = {Cloud Architect Project, Programme H4036},
  url          = {https://github.com/leobagno-labs/leomulticloud}
}
```

> A Zenodo DOI will be added here after registration.

---

## References

- Li, W. et al. (2025). Multi-Cloud Management Architecture Design and Disaster Recovery Strategy for High Availability. *Journal of Cyber Security and Mobility*, 14(5), pp. 1173–1198.
- Tong, W. (2023). Cloud native application disaster recovery in a multi-cloud environment – a DevOps approach using Terraform. MSc thesis, National College of Ireland.
- Vironica, Y., Hertiana, S. and Karna, N. (2025). Evaluating Azure Site Recovery for disaster recovery. *ISITIA 2025*. IEEE.
- Suyatno, T., Ferdiana, R. and Widyawan (2025). Disaster Recovery Strategy: RTO and RPO Analysis on On-Premises and Cloud Infrastructure. *ICADEES 2025*. IEEE.
- Amazon Web Services (2025). Summary of the Amazon DynamoDB Service Disruption in the Northern Virginia (US-EAST-1) Region.

---

## License

MIT License © 2026 Leonardo Bagno — see [LICENSE](LICENSE) for the full text.
