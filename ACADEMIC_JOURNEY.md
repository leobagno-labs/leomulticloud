# Academic Journey — Leo — Multi-Cloud Disaster Recovery

## TU Dublin | Leonardo Bagno | Academic Year 2026

---

## Why This Project Exists

My professional background is in data center operations. In physical infrastructure, redundancy is never optional: power, network links, and critical components are always provisioned with backups, and a single failure should not bring down a service.

Cloud platforms are highly redundant, but real incidents still demonstrate that a regional disruption can degrade multiple services at once. This project treats those incidents as motivation (background) and focuses on what can be objectively measured in a controlled experiment: **DNS-based failover behaviour**, **TTL impact**, and **recovery performance** in a **multi-cloud active–passive design**. 

This project designs, implements, and empirically evaluates a **multi-cloud disaster recovery architecture** using **AWS as primary** and **Azure as secondary**, with automated DNS failover using **Route 53 health checks** and a controlled test methodology.

---

## What This Project Actually Builds (Current Scenario)

### Deployment model (simplified for reproducible measurement)

- **No Docker** (to reduce extra runtime layers and measurement noise)
- **Ubuntu 22.04 VM on AWS + Ubuntu 22.04 VM on Azure**
- **Flask app served by Gunicorn**
- **Nginx reverse proxy** in front of Gunicorn
- **systemd** manages the Gunicorn service (auto-start and restart)
- **/health endpoint** exposed via Nginx for Route 53 health checks
- The application identifies **which cloud is serving the request** (AWS or Azure)

### Provisioning & symmetry

-### Provisioning & symmetry

- Deployment is automated via a cloud-init cloud-config (user-data) file executed at first boot on both AWS EC2 and Azure VM, which installs and configures Nginx + Gunicorn + systemd and validates the `/health` endpoint.
- Infrastructure is created with Terraform and structured to keep AWS/Azure stacks as equivalent as practical.
- Global DNS failover is implemented with Route 53 failover routing policy + health checks.

---

## Research Focus (What I Measure)

This project is not “multi-cloud is better” as a broad claim. The focus is **measurable behaviour** of DNS-based disaster recovery in a reproducible multi-cloud environment:

1) **RTO (Recovery Time Objective) / Failover Time**
   - Measured from “primary becomes unhealthy” to “clients consistently receive responses from secondary”.
   - Includes detection and DNS caching/propagation effects. 

2) **TTL as a controlled variable**
   - Failover is tested with **TTL = 60s, 120s, 300s** (all other variables held constant).
   - This isolates how caching behaviour contributes to total recovery duration. 

3) **RPO (Recovery Point Objective)**
   - The Flask app is **stateless by design**, therefore **RPO = 0** (no database, no sessions, no persistent writes).
   - This is justified as a valid DR workload model: there is no state to lose. 

4) **Failback**
   - Time to return traffic from Azure → AWS after recovery is measured as a distinct experiment.

---

## Literature Alignment (What the Literature Supports / What I Add)

The literature supports:

- Multi-cloud disaster recovery strategies and HA design patterns (Li et al., 2025).
- Terraform for multi-cloud provisioning and reproducibility (Ghosh et al., 2024; Manolov et al., 2024).
- Empirical measurement of RTO/RPO in DR contexts, but usually without isolating DNS behaviour (Suyatno et al., 2025; Vironica et al., 2025).
- DNS TTL behaviour is not always “standard” across resolvers, which affects caching/propagation (Shavitt and Shreibstein, 2025).

What this project adds (in a controlled and reproducible way):

- **DNS TTL isolated as an experimental variable** (60/120/300) during multi-cloud failover testing.
- **Joint reporting** of RTO + TTL impact + failback timing, within one consistent architecture and test suite. 

---

## What I Will Deliver

- A documented multi-cloud DR architecture (AWS primary + Azure secondary)
- Terraform codebase (reproducible provisioning)
- A bootstrap script (cloud-init user_data) that deploys:
  - Flask + Gunicorn + Nginx
  - systemd service unit
  - `/health` endpoint validation
- A set of tests that record:
  - failover time (RTO)
  - TTL impact across 60/120/300
  - RPO justification (stateless = 0)
  - failback time
- A final report that evaluates results against the research questions and limitations of DNS-based DR. 

---

## Key Insight (One Sentence)

This project empirically evaluates DNS-based multi-cloud disaster recovery by isolating TTL as a variable and measuring failover/failback behaviour in a reproducible Terraform-managed AWS + Azure environment, while using a stateless workload model (RPO = 0 by design). 

---

**Repository:** github.com/your-username/leomulticloud  
**Status:** App working locally + deployment artefacts being implemented (user_data, systemd unit, nginx config, Terraform)  
**Target completion:** April 17, 2026
