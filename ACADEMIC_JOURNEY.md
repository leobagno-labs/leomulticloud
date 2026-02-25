# Academic Journey - Leo - MultiCloud Disaster Recovery
**TU Dublin | Leonardo Bagno | 2026**

---

## Why This Project Exists

My professional background is in data center operations. In physical infrastructure, redundancy is never optional. Therefore, servers, network links, and power supplies are always provisioned with backup. The failure of a single component should never bring down a service.

The **AWS us-east-1 outage in December 2021** changed how I looked at cloud architecture. Major services went down for hours. Organisations that depended on a single cloud provider had exactly the same problem that data center best practices solve on day one: a **single point of failure**.

That observation raised a natural question:

> *"If we implement redundancy by default in physical infrastructure, why are organisations still running single-cloud architectures in the cloud?"*

This project answers that question — by building, deploying, and empirically measuring a multi-cloud disaster recovery architecture using **AWS as primary** and **Azure as secondary**, with automated DNS failover via **Route 53**.

---

## What the Literature Found

### The Problem — Nelson et al. (2025)
Between 2017 and 2023, AWS recorded **five major outages** affecting multiple regions simultaneously. The study concluded that single-cloud architectures — regardless of internal redundancy — remain vulnerable to provider-level failures.

> Nelson, J., Patel, R., & Thompson, K. (2025). Cloud Service Reliability and Disaster Recovery in Enterprise Environments. *Journal of Cloud Computing*, 14(2), 1–18.

### The Gap — Kopparthi (2024)
Only **32% of organisations** achieve RTO under 2 hours with single-cloud Warm Standby architectures. The remaining 68% depend on manual processes that significantly increase recovery time. Automation via IaC was identified as the key missing element.

> Kopparthi, S. (2024). Multi-Cloud Disaster Recovery: Strategies and Implementation. *International Journal of Cloud Computing and Services Science*, 13(1), 45–62.

### The Closest Work — Tong (2023)
Measured Terraform provisioning time (300–360 seconds) and demonstrated a 75–85% reduction in RTO compared to manual provisioning. However, Tong simulated DR by **destroying the entire infrastructure** — a worst-case scenario that does not represent a realistic application failure. No measurement of RPO, TTL variation, or failback was performed.

> Tong, W. (2023). Automated Cloud Infrastructure Provisioning for Disaster Recovery Using Terraform. *IEEE International Conference on Cloud Engineering*, 112–119.

---

## What No Paper Has Done — The Gap This Project Fills

| Metric | Tong (2023) | Kopparthi (2024) | Nelson et al. (2025) | **This Project** |
|---|---|---|---|---|
| RTO measured |  Yes |  Partial |  Defined only |  **Yes** |
| RPO measured |  No |  Theoretical |  Defined only |  **Yes** |
| TTL as variable |  No |  No |  No |  **Yes** |
| Failback tested |  No |  No |  No |  **Yes** |
| Reproducible |  Partial |  No |  No |  **Yes** |

---

## What This Project Proposes

### Problem 1 — Single cloud dependency
**Literature:** Nelson et al. (2025) documented provider-level failures affecting organisations with no cross-cloud redundancy.  
**This project:** Deploys identical application stacks on AWS (primary) and Azure (secondary). Route 53 automatically redirects traffic when the primary fails — no manual intervention.

### Problem 2 — Manual DR processes with high RTO
**Literature:** Kopparthi (2024) found 68% of organisations cannot achieve RTO < 2 hours due to manual recovery processes.  
**This project:** Entire infrastructure provisioned by a single `terraform apply` command. RQ2 measures whether Tong's 300–360 second benchmark is reproducible in a real AWS+Azure environment.

### Problem 3 — No simultaneous RTO + RPO measurement
**Literature:** No reviewed paper measured both metrics simultaneously in a real multi-cloud environment.  
**This project:** Measures RTO (failover time) and RPO (data loss) simultaneously during the same test run. The stateless Flask application guarantees RPO = 0 by design — no database, no sessions, no state to lose.

### Problem 4 — TTL never isolated as a variable
**Literature:** Tong (2023) mentions TTL briefly but never varies it systematically.  
**This project:** Tests failover with TTL = 60s, 120s, and 300s — keeping all other variables constant. This is the most methodologically original contribution of the project.

### Problem 5 — Failback never measured
**Literature:** No reviewed paper measured the time to return to the primary cloud after DR.  
**This project:** Measures failback time (Azure → AWS) as a distinct test, adding a dimension absent from all reviewed literature.

---

*"The architecture I am designing directly addresses these three gaps in the literature: it uses two distinct clouds to eliminate the single point of failure, uses Terraform to eliminate manual intervention, and measures RTO, RPO, and TTL simultaneously in a reproducible environment with a budget under €15."*

---

**Project repository:** [github.com/your-username/leomulticloud](https://github.com/your-username/leomulticloud)  
**Status:** Phase 1 complete — Flask app running locally  
**Target completion:** April 17, 2026
