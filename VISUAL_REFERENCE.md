# Code Signing Tokens - Visual Reference Guide

## Complete System Flow

### 1. Token Lifecycle

```
TIMELINE: Token Lifecycle
─────────────────────────────────────────────────────────────

STEP 1: SPONSORSHIP
┌─────────────────────────────────┐
│ User becomes sponsor            │
│ (GitHub/Stripe/PayPal)          │
│ Tier 1 minimum required         │
└────────────┬────────────────────┘
             │
STEP 2: REQUEST TOKEN
┌────────────▼────────────────────┐
│ Email support@amidaware.com     │
│ Include: Discord & GitHub ID    │
│          API subdomain          │
└────────────┬────────────────────┘
             │
STEP 3: TOKEN GENERATION (24 hours)
┌────────────▼────────────────────┐
│ Amidaware generates token       │
│ Validates sponsorship status    │
│ Creates auth credentials        │
└────────────┬────────────────────┘
             │
STEP 4: TOKEN DELIVERY
┌────────────▼────────────────────┐
│ Token sent via email            │
│ One token per instance          │
│ Sponsor stores securely         │
└────────────┬────────────────────┘
             │
STEP 5: ACTIVE USE
┌────────────▼────────────────────┐
│ Configured in Tactical RMM      │
│ Used automatically for agents   │
│ No further action needed        │
└─────────────────────────────────┘

MAINTENANCE:
┌──────────────────────────────────────────┐
│ If compromised:                          │
│ → Email support → Token invalidated      │
│ → Request replacement → New token sent   │
└──────────────────────────────────────────┘
```

---

## 2. Agent Generation Flow

```
ADMIN USER INTERFACE
┌────────────────────────────────────┐
│ Agents → Install Agent             │
│ Select: Client, Site               │
│         Type, Architecture         │
│         Token Expiry               │
└────────────┬─────────────────────────
             │
AGENT REQUEST GENERATION
             ▼
┌────────────────────────────────────┐
│ REST API: POST /api/agents/generate│
│ Class: GenerateAgent(APIView)      │
│ Permissions: AllowAny              │
└────────────┬─────────────────────────
             │
TOKEN LOOKUP
             ▼
┌────────────────────────────────────┐
│ Load CODE_SIGNING_TOKEN from:      │
│ - Environment variable, OR         │
│ - Django settings, OR              │
│ - Database (encrypted)             │
└────────────┬─────────────────────────
             │
AMIDAWARE SIGNING REQUEST
             ▼
┌────────────────────────────────────┐
│ HTTP POST to Amidaware servers     │
│ URL: codesigning.amidaware.com/...  │
│ Header: Authorization: Bearer TOKEN│
│ Body: Unsigned agent binary        │
└────────────┬─────────────────────────
             │
TOKEN VALIDATION AT AMIDAWARE
             ▼
        ┌────────────┐
        │ Is token   │
        │ valid?     │
        └─────┬──────┘
         YES  │  NO
             ╱ ╲
        ┌───▼─┐ ┌──────────┐
        │YES  │ │NO/FAIL   │
        └─┬──┘ └──────┬───┘
          │           │
          ▼           ▼
    ┌──────────┐  ┌──────────────┐
    │Sign with │  │Return unsigned│
    │Amidaware │  │agent (graceful│
    │cert      │  │fallback)      │
    └────┬─────┘  └────┬─────────┘
         │             │
         └──────┬──────┘
                ▼
        RETURN AGENT BINARY
                ▼
    ┌──────────────────────────┐
    │ Return as file download  │
    │ OR deployment link       │
    │ OR via direct download   │
    └──────────────────────────┘
```

---

## 3. Installation Methods Comparison

```
┌──────────────────────────────────────────────────────────────┐
│ INSTALLATION METHOD DECISION MATRIX                         │
├──────────────────────────────────────────────────────────────┤

WINDOWS
├─ Deployment Link (Dynamic EXE)
│  ├─ Requires: Code signing token configured
│  ├─ Process: Download link → Execute EXE → Auto-register
│  ├─ Best for: Mass deployment, one-time use
│  ├─ Security: URL-safe random token, time-limited
│  └─ Signed: Yes (if token valid)
│
└─ Manual Installation (Inno Setup)
   ├─ Requires: CLI parameters (--auth, --api, etc.)
   ├─ Process: Download EXE → Run with params → Register
   ├─ Best for: Individual installations, scripted deployment
   ├─ Security: Requires auth token in command
   └─ Signed: Yes (always, with DigiCert cert)

LINUX (Official)
├─ Deployment Script
   ├─ Requires: Code signing token
   ├─ Process: Download script → chmod +x → Execute
   ├─ Best for: Automated deployment, standard systems
   ├─ Security: Embedded credentials in script
   ├─ Arch support: systemd-based distros
   └─ Signed: Yes (if token valid)

LINUX (Community Alternative)
├─ No Token Required Script
   ├─ Repository: github.com/netvolt/LinuxRMM-Script
   ├─ Process: wget → chmod +x → Execute with params
   ├─ Best for: Testing, no sponsorship
   ├─ Security: Manual parameter passing
   ├─ Arch support: All Linux (including QNAP)
   └─ Signed: No (unsigned agent, community maintained)

macOS
├─ Similar to Linux
   ├─ Requires: Code signing token
   ├─ Process: Similar script-based deployment
   ├─ Arch support: Intel and Apple Silicon
   └─ Signed: Yes (with Amidaware cert)

└─ Key Difference: Code signing token is REQUIRED for official
   Linux/macOS but NOT for unsigned Windows installations
```

---

## 4. Token Storage Architecture

```
TOKEN STORAGE OPTIONS & SECURITY LEVELS
────────────────────────────────────────

OPTION 1: Environment Variables (Recommended)
┌──────────────────────────────────────┐
│ .env or deployment configuration     │
│ CODE_SIGNING_TOKEN=<token>           │
│ Loaded at: Application startup       │
│ Security: High (OS-level protection) │
│ Issue: Requires restart to update    │
└──────────────────────────────────────┘

OPTION 2: Secrets Vault (Enterprise)
┌──────────────────────────────────────┐
│ HashiCorp Vault, AWS Secrets, etc.   │
│ Retrieved at: Runtime                │
│ Security: Highest (centralized)      │
│ Access: Audit-logged, rotated easily │
└──────────────────────────────────────┘

OPTION 3: Database (Encrypted)
┌──────────────────────────────────────┐
│ Django CodeSigningToken model        │
│ Retrieved at: Runtime                │
│ Security: High (encrypted at rest)   │
│ Issue: Must encrypt sensitive field  │
└──────────────────────────────────────┘

⚠️ NEVER: Commit to version control!
   ├─ No hardcoding in Python files
   ├─ No in configuration files
   └─ No in Docker images

SECURITY FLOW:
Token in Vault/Env
    ↓
Load into Django settings at startup
    ↓
CodeSigningService retrieves token
    ↓
Only used for HTTPS requests to Amidaware
    ↓
Never logged or displayed to users
```

---

## 5. Deployment Link Token Flow

```
DEPLOYMENT LINK CREATION & USAGE
─────────────────────────────────

CREATION (Admin UI)
┌──────────────────────────────────────┐
│ Admin generates deployment link      │
│ Specifies: Client, Site, Type,       │
│            Architecture, Expiry       │
└────────────┬─────────────────────────┘
             ▼
┌──────────────────────────────────────┐
│ Database: Create DeploymentLink      │
│ ├─ token: random 128-char string    │
│ ├─ client_id: <id>                   │
│ ├─ site_id: <id>                     │
│ ├─ agent_type: windows/linux/macos   │
│ ├─ expiry_date: now + X days         │
│ └─ is_active: true                   │
└────────────┬─────────────────────────┘
             ▼
┌──────────────────────────────────────┐
│ Generate shareable URL               │
│ https://api.yourdomain.com/deploy/   │
│   5f7a9c3e2b1d4a6e8f0c2b4d6a8e0f2c   │
└────────────┬─────────────────────────┘
             ▼
        SHARE WITH USER

USAGE (Installation)
┌──────────────────────────────────────┐
│ User accesses deployment URL         │
│ GET /deploy/TOKEN                    │
└────────────┬─────────────────────────┘
             ▼
┌──────────────────────────────────────┐
│ Validate token:                      │
│ ├─ Token exists in database          │
│ ├─ Not expired                       │
│ ├─ Is_active = true                  │
│ ├─ Client/site matches               │
│ └─ Architecture valid                │
└────────────┬─────────────────────────┘
             ▼
       ┌─────┴─────┐
       │ Valid?    │
       └─────┬─────┘
        YES  │  NO
            ╱ ╲
       ┌────▼─┐ ┌─────────────────┐
       │YES   │ │NO - Show error  │
       └──┬───┘ └─────────────────┘
          ▼
┌──────────────────────────────────────┐
│ Load code signing token from config  │
│ Request signed agent from Amidaware  │
│ (If available)                       │
└────────────┬─────────────────────────┘
             ▼
┌──────────────────────────────────────┐
│ Return agent (signed or unsigned)    │
│ Log usage in DeploymentLinkLog       │
│ ├─ timestamp                         │
│ ├─ IP address                        │
│ ├─ signed: true/false                │
│ └─ user_agent                        │
└────────────┬─────────────────────────┘
             ▼
       AGENT DOWNLOADED
```

---

## 6. Error Handling Decision Tree

```
AGENT GENERATION ERROR HANDLING
───────────────────────────────

START: Request agent
  │
  ├─ No token configured?
  │  └─ Return unsigned agent ✓
  │
  ├─ Token configured, attempt signing
  │  │
  │  ├─ Can reach Amidaware?
  │  │  │
  │  │  ├─ NO (Network error)
  │  │  │  └─ Fallback: Return unsigned ✓
  │  │  │     Log warning: Signing server unreachable
  │  │  │
  │  │  └─ YES: Request signing
  │  │     │
  │  │     ├─ Status 200 (Success)
  │  │     │  └─ Return signed agent ✓
  │  │     │
  │  │     ├─ Status 401/403 (Invalid token)
  │  │     │  └─ Return unsigned ⚠
  │  │     │     Log error: Token invalid
  │  │     │     Alert admin: Check token
  │  │     │
  │  │     ├─ Status 400 (Bad request)
  │  │     │  └─ Return unsigned ⚠
  │  │     │     Log error: Bad request to signing server
  │  │     │
  │  │     └─ Status 5xx (Server error)
  │  │        └─ Return unsigned ⚠
  │  │           Log warning: Signing server error
  │
  └─ Exception during signing
     └─ Return unsigned ✓
        Log error: Exception details

KEY PRINCIPLE: Always graceful fallback
  ├─ Unsigned agents still work
  ├─ Higher AV false positive rate
  ├─ Cannot be whitelisted easily
  └─ But deployment continues
```

---

## 7. API Endpoint Reference

```
CODE SIGNING & AGENT MANAGEMENT ENDPOINTS
──────────────────────────────────────────

POST /api/agents/generate
├─ Purpose: Generate signed/unsigned agent
├─ Auth: AllowAny (public endpoint)
├─ Input:
│  ├─ client_id (required): integer
│  ├─ site_id (required): integer
│  ├─ agent_type (required): "server"|"workstation"
│  ├─ arch (optional): "64"|"32" (default: "64")
│  ├─ os_type (optional): "windows"|"linux"|"macos"
│  └─ token_expiry (optional): days (default: 1)
├─ Output: Binary executable/script file
└─ Status Codes:
   ├─ 200: Agent generated (signed or unsigned)
   ├─ 400: Missing/invalid parameters
   └─ 500: Server error

POST /api/deployments/create
├─ Purpose: Create deployment link
├─ Auth: Admin only
├─ Input: deployment parameters
├─ Output: Deployment token & URL
└─ Status Codes: 200 | 400 | 401 | 403 | 500

GET /api/agents/token-status
├─ Purpose: Check signing token status
├─ Auth: Admin only
├─ Output:
│  ├─ configured: boolean
│  ├─ valid: boolean
│  └─ signing_enabled: boolean
└─ Status Codes: 200 | 401 | 403

GET /api/agents/install/{os}?client_id=X&site_id=Y
├─ Purpose: Download installation script
├─ Auth: AllowAny
├─ Params: client_id, site_id, arch (optional)
├─ Output: Installation shell script
└─ Status Codes: 200 | 400 | 500

POST /api/agents/register
├─ Purpose: Register new agent with server
├─ Auth: AllowAny (with deployment token)
├─ Input: Agent details + deployment token
└─ Output: Registration confirmation
```

---

## 8. Security Checklist

```
SECURITY IMPLEMENTATION CHECKLIST
──────────────────────────────────

TOKEN PROTECTION
☐ Store in environment variables, NOT code
☐ Use secrets vault for enterprise deployments
☐ Encrypt at rest (database level)
☐ Never log actual token value
☐ HTTPS-only transmission to Amidaware
☐ Access limited to authenticated admins
☐ Rotate if compromise suspected
☐ Audit all token access/modifications

DEPLOYMENT LINK SECURITY
☐ Use cryptographically secure random tokens
☐ Set appropriate expiry times
☐ Log all download attempts
☐ Track IP addresses for suspicious activity
☐ Allow revocation of links
☐ Monitor link reuse patterns

AGENT EXECUTION SECURITY
☐ Windows: Runs as SYSTEM (privileged)
☐ Linux: Runs as root or tactical user
☐ macOS: Appropriate user permissions
☐ All platforms: HTTPS for communication
☐ Certificate pinning (optional)
☐ Signed agent verification

CODE SIGNING CERTIFICATE SECURITY
☐ Using Amidaware Code Signing Root CA (as of May 2024)
☐ Hardware tokens/HSM protected (Amidaware's responsibility)
☐ Regular certificate rotation
☐ Public key available for verification
☐ Inno Setup installers: DigiCert OV signed

ERROR HANDLING SECURITY
☐ Never expose token in error messages
☐ Don't log sensitive parameters
☐ Graceful degradation (unsigned fallback)
☐ Clear admin alerts for failures
☐ Detailed logs for troubleshooting (admin only)
```

---

## 9. Key Statistics & Limits

```
TOKEN SPECIFICATIONS
────────────────────

Sponsorship Requirement:
├─ Minimum Tier: 1
├─ Platforms: GitHub Sponsors, Stripe, PayPal
└─ Non-refundable: Yes, after token delivery

Token Validity:
├─ Scope: One token per Tactical RMM instance
├─ Multi-instance: Contact support for pricing
├─ Expiry: Typically until sponsorship ends
└─ Compromise recovery: Support ticket for replacement

Agent Signing:
├─ Platforms: Windows, Linux, macOS
├─ Certificate: Amidaware Code Signing Root CA
├─ Processing time: ~1-2 seconds per agent
├─ Timeout: 30 seconds (fallback to unsigned)
└─ Fallback behavior: Always returns unsigned if signing fails

Deployment Link Tokens:
├─ Token length: 128 characters (URL-safe)
├─ Default expiry: Configurable (typically 1-7 days)
├─ Reusability: Until expiration
├─ Scope: Client-specific, Site-specific
└─ Audit: Logged with IP, timestamp, user agent

API Response Times:
├─ Generate agent: <5 seconds (without signing)
├─ With signing: 3-5 seconds (Amidaware dependent)
├─ Token validation: <1 second
├─ Deployment link creation: <1 second
└─ Installation script generation: <1 second
```

---

## 10. Common Scenarios Quick Answer

```
SCENARIO: I want to deploy agents without sponsorship
└─ Use community Linux script or unsigned agents
   └─ https://github.com/netvolt/LinuxRMM-Script

SCENARIO: I want code-signed Linux agents
└─ Get code signing token (sponsor Tier 1 minimum)
└─ Configure in Tactical RMM
└─ Agents automatically signed on generation

SCENARIO: My token doesn't work
└─ Verify token in settings: grep CODE_SIGNING_TOKEN config
└─ Test connectivity to Amidaware
└─ Email support@amidaware.com with Discord/GitHub username
└─ Check sponsorship is still active

SCENARIO: I suspect my token was compromised
└─ Email support@amidaware.com immediately
└─ Request invalidation of old token
└─ Request new token generation
└─ Wait 24 hours for new token delivery

SCENARIO: I want to share agent installation with team
└─ Generate deployment link from Admin UI
└─ Link is valid for specified time period
└─ No auth tokens needed to use link
└─ Monitor usage in audit logs

SCENARIO: I'm getting "Missing code signing token" error
└─ For Windows: Unsigned agent will be delivered (OK)
└─ For Linux: Installation may fail without code signing token
└─ Solution: Get sponsorship OR use community script

SCENARIO: I want audit logs of agent installations
└─ Deployment links: Logged automatically
└─ Direct downloads: Check API access logs
└─ Agent registration: Stored in database
└─ Code signing requests: Logged with timestamps
```

