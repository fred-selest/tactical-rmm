# Tactical RMM Code Signing Tokens - Quick Reference Guide

## Essential Information At A Glance

### What Are Code Signing Tokens?
Authentication credentials that allow your Tactical RMM instance to request code-signed agent binaries from Amidaware's servers. This reduces antivirus false positives and enables security software whitelisting.

### How to Get One
1. Become a GitHub/Stripe/PayPal sponsor (minimum Tier 1)
2. Email: support@amidaware.com with Discord & GitHub usernames
3. Provide your API subdomain (e.g., api.yourdomain.com)
4. Wait 24 hours for delivery

### Token Workflow
```
You request agent → Code signing token sent to Amidaware → 
Validated → Signed agent returned → Delivered to user
```

---

## Linux Agent Installation

### Option 1: Official Method (Requires Code Signing Token)
```bash
# Download from Tactical RMM UI: Agents → Install Agent
chmod +x rmm-clientname-sitename-type.sh
./rmm-clientname-sitename-type.sh
```

### Option 2: Community Script (No Token Required)
```bash
wget https://raw.githubusercontent.com/netvolt/LinuxRMM-Script/main/rmmagent-linux.sh
chmod +x rmmagent-linux.sh
./rmmagent-linux.sh install 'MeshAgent' 'https://api.yourdomain.com' \
  'CLIENT_ID' 'SITE_ID' 'AUTH_TOKEN' 'server'
```

---

## Where Code Is Located

**Main Project**: https://github.com/amidaware/tacticalrmm

**Key Files**:
- Agent generation API: `api/tacticalrmm/clients/views.py` (GenerateAgent class)
- Linux installation script: `api/tacticalrmm/core/agent_linux.sh`
- Django settings: `tacticalrmm/settings/`

---

## API Endpoints

| Endpoint | Purpose | Auth |
|----------|---------|------|
| POST /api/agents/generate | Generate agent binary | Token required |
| POST /api/deployments/create | Create deployment link | Admin only |
| GET /api/agents/install/linux | Download Linux installer | Public (token checked) |
| POST /api/agents/register | Register new agent | Deployment token |

---

## Common Issues

| Issue | Solution |
|-------|----------|
| "Missing code signing token" | Configure token in backend settings |
| Unsigned agents downloading | Verify token is valid & not expired |
| Linux agent won't install | Ensure code signing token is set, or use community script |
| Agent can't register | Check auth token in installation parameters |

---

## Security Best Practices

- Store token in environment variables, NOT source code
- Use HTTPS for all agent communications
- Rotate token if compromise suspected
- Limit admin access to token configuration
- Monitor deployment link expiry dates

---

## Important Links

- Documentation: https://docs.tacticalrmm.com/code_signing/
- GitHub: https://github.com/amidaware/tacticalrmm
- Community Linux Script: https://github.com/netvolt/LinuxRMM-Script
- Support Email: support@amidaware.com

