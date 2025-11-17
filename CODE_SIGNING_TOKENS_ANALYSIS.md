# Tactical RMM Code Signing Tokens - Comprehensive Analysis

## Repository Status

**Current Repository**: `/home/user/tactical-rmm`
- **Type**: Feature branch for implementing code signing tokens
- **Branch**: `claude/tactical-rmm-signing-token-01M6rUrmv2r4KUtH7AdBdUuL`
- **Status**: Currently contains only initial commit with LICENSE and README files
- **Remote**: `http://local_proxy@127.0.0.1:17531/git/fred-selest/tactical-rmm`
- **Description**: New feature branch for Tactical RMM integration with code signing tokens

---

## 1. CODE SIGNING TOKENS - OVERVIEW

### Purpose
Code signing tokens authenticate your self-hosted Tactical RMM instance to receive digitally signed agents from Amidaware's code signing servers. This helps reduce antivirus false positives and enables security software whitelisting.

### How They Work (Flow Diagram)

```
Your Tactical RMM Instance
        ↓
   (Generates or updates agent)
        ↓
   Sends HTTP request to Amidaware's code signing server
        ↓
   Includes authentication token in request
        ↓
   Amidaware server validates token
        ↓
   ├─ Token Valid → Returns code-signed agent binary
   └─ Token Invalid → Returns unsigned agent binary
        ↓
   Agent delivered to deployment link or direct download
```

### Key Characteristics
- **One token per instance**: Each self-hosted Tactical RMM instance gets one unique token
- **Multi-platform support**: Single token enables code signing for Windows, Linux, and macOS agents
- **Certificate Authority**: Signed with Amidaware's own Code Signing Root CA (as of May 2024)
- **Automatic flow**: Works transparently when generating agents or during agent self-updates

---

## 2. OBTAINING CODE SIGNING TOKENS

### Prerequisites
- Must be a sponsor with minimum **Tier 1 monthly sponsorship**
- Sponsorship can be through GitHub Sponsors, Stripe, or PayPal

### Process
1. Become a sponsor on one of the supported platforms
2. Open a support ticket selecting "Code Signing Request"
3. Provide required information:
   - Discord username
   - GitHub username
   - Payment method confirmation
   - API subdomain (e.g., api.yourdomain.com)
4. Allow up to 24 hours for token generation and delivery

### Important Notes
- **Non-refundable**: Once you receive a code signing token, the sponsorship becomes non-refundable
- **Support contact**: support@amidaware.com
- **Token security**: If token is compromised, email support immediately for invalidation/replacement
- **Tier requirement**: Sponsorship tier must be at minimum Tier 1 to qualify

---

## 3. TOKEN GENERATION AND STORAGE (IMPLEMENTATION DETAILS)

### Where Tokens Are Generated
- **Server**: Amidaware's code signing server infrastructure
- **Trigger**: After payment verification and sponsor confirmation
- **Delivery**: Provided to sponsor via support email

### Where Tokens Are Stored (in Tactical RMM Instance)
- **Location**: In the Tactical RMM Django backend database and configuration
- **Configuration point**: During initial setup or through admin settings
- **Access control**: Only accessible to authenticated backend administrators
- **Storage type**: Encrypted storage recommended (at filesystem/database level)

### Token Validation
- Happens on-demand when:
  - Agent installer is generated
  - Agent performs self-update
  - Deployment links are created (especially for Linux agents)
- Connection is made to Amidaware's code signing servers
- Response indicates validity and whether to provide signed or unsigned agent

---

## 4. AGENT INSTALLATION PROCESS

### Windows Agent Installation

#### Method 1: Deployment Link (Dynamic EXE)
```
1. Login to Tactical RMM UI
2. Navigate to Agents → Install Agent
3. Select:
   - Client
   - Site
   - Server or Workstation
   - Architecture
   - Token expiry duration
4. Choose "Deployment Link"
5. System generates dynamic EXE with code signing token embedded
6. Share link with target machine
7. Execute installer
8. Agent registers with server and receives mesh agent
```

**Code Location**: `tacticalrmm/api/tacticalrmm/clients/views.py`
- Class: `GenerateAgent(APIView)` (Lines 349-380)
- Method: `generate_winagent_exe()`
- Permissions: `AllowAny` (public endpoint for downloads)

#### Method 2: Manual Installation (Signed Inno Setup)
```
1. Login to Tactical RMM UI
2. Navigate to Agents → Install Agent
3. Copy the installation command (contains --auth flag)
4. Download installer from permanent link:
   - `tacticalagent-vX.X.X-windows-[arch].exe`
   - Signed with Digicert OV certificate
5. Execute installer with authentication parameters
6. Agent contacts server and completes registration
```

**Parameters**:
```
tacticalagent.exe --api https://api.yourdomain.com ^
                  --auth <AUTH_TOKEN> ^
                  --client-id <CLIENT_ID> ^
                  --site-id <SITE_ID>
```

### Linux Agent Installation

#### Official Method (Requires Code Signing Token)
```bash
# 1. Login to Tactical RMM UI
# 2. Navigate to Agents → Install Agent
# 3. Select: Client, Site, Type (Server/Workstation), Architecture, Linux

# 4. Download generated script
# Script name: rmm-<CLIENT>-<SITE>-<TYPE>.sh

# 5. On target Linux machine:
chmod +x rmm-clientname-sitename-type.sh
./rmm-clientname-sitename-type.sh

# 6. Script performs:
#    - Downloads Go-based agent binary
#    - Downloads Mesh agent for remote access
#    - Configures systemd service
#    - Registers with Tactical RMM instance
```

**Note**: Linux agents require code signing tokens to generate deployment links

#### Community Alternative (No Code Signing Required)
- **Repository**: https://github.com/netvolt/LinuxRMM-Script
- **Purpose**: Allows Linux agent installation without code signing sponsorship
- **Script location**: https://raw.githubusercontent.com/netvolt/LinuxRMM-Script/main/rmmagent-linux.sh

```bash
# Community script approach:
wget https://raw.githubusercontent.com/netvolt/LinuxRMM-Script/main/rmmagent-linux.sh
sudo chmod +x rmmagent-linux.sh
./rmmagent-linux.sh install 'Mesh agent' 'API_URL' 'CLIENT_ID' 'SITE_ID' 'AUTH_KEY' 'TYPE'

# Example:
./rmmagent-linux.sh install 'MeshAgent' 'https://api.company.com' '1' '2' 'auth_token_here' 'server'
```

#### Configuration File Method (Non-SystemD Systems)
```bash
# For QNAP and non-systemD Linux distributions
# Create configuration file with:
AGENT_DL="<agent binary URL>"
MESH_DL="<mesh agent URL>"
API_URL="https://api.yourdomain.com"
TOKEN="<auth token>"
CLIENT_ID="1"
SITE_ID="2"
AGENT_TYPE="server"
PROXY="<optional proxy>"
```

**Relevant Code Location**: `api/tacticalrmm/core/agent_linux.sh`
- Official Linux agent installation script
- Located in main Tactical RMM repository
- Handles: agent download, configuration, service registration

### macOS Agent Installation
- Requires code signing sponsorship (similar to Linux)
- Scripts and binaries generated through same token validation system
- Code signing with Amidaware certificate for whitelisting

---

## 5. API ENDPOINTS FOR TOKEN AND AGENT MANAGEMENT

### Code Signing Related Endpoints

#### Generate Agent Endpoint
```
Endpoint: POST /api/agents/generate
Location: tacticalrmm/api/tacticalrmm/clients/views.py
Class: GenerateAgent(APIView)
Permissions: AllowAny

Parameters:
{
    "client_id": <integer>,
    "site_id": <integer>,
    "agent_type": "server" | "workstation",
    "arch": "64" | "32",
    "token_expiry": <days>
}

Response:
- If token valid: Code-signed executable binary
- If token invalid: Unsigned executable binary
```

#### Deployment Links Endpoint
```
Endpoint: POST /api/deployments/create
Purpose: Create deployment tokens for bulk agent distribution
Features:
- Generates unique deployment tokens
- Associates with specific client/site
- Sets expiry date
- Returns shareable deployment link
```

#### Agent Installation Script Endpoints
```
Windows Manual:
GET /api/agents/install/windows?client_id=X&site_id=Y&arch=64

Linux:
GET /api/agents/install/linux?client_id=X&site_id=Y&arch=64

macOS:
GET /api/agents/install/macos?client_id=X&site_id=Y&arch=64

Response: Download installation script with embedded authentication
```

### Agent Registration and Updates

#### Agent Registration
```
Endpoint: POST /api/agents/register
Purpose: Register new agent with server

Payload:
{
    "client_id": <integer>,
    "site_id": <integer>,
    "auth_key": "<deployment token>",
    "hostname": "COMPUTER-NAME",
    "agent_version": "X.X.X",
    "os": "windows|linux|macos"
}
```

#### Agent Self-Update
```
Flow:
1. Agent checks for updates via API
2. If update available, requests signed binary
3. Server sends request to Amidaware with code signing token
4. Receives signed executable
5. Agent downloads and applies update

Code signing token automatically used for self-update verification
```

---

## 6. TOKEN GENERATION AND RETRIEVAL MECHANISMS

### Server-Side Storage
Location: Django backend configuration
- Token stored in: `tacticalrmm/settings/` or database secrets table
- Access: Only available to backend during HTTP requests to Amidaware
- Environment variable: Likely `CODE_SIGNING_TOKEN` or similar

### Token Usage Flow

```python
# Pseudocode for token usage in agent generation

def generate_agent():
    # 1. Retrieve stored token
    token = get_code_signing_token()
    
    # 2. Prepare agent binary
    agent_binary = build_agent_binary()
    
    # 3. Send to code signing server
    response = requests.post(
        "https://codesigning.amidaware.com/sign",
        headers={"Authorization": f"Bearer {token}"},
        data=agent_binary
    )
    
    # 4. Handle response
    if response.status_code == 200:
        signed_agent = response.content  # Code-signed binary
    else:
        signed_agent = agent_binary  # Fallback to unsigned
    
    return signed_agent
```

### Deployment Token Generation
```
Process:
1. Admin user clicks "Generate Deployment Link"
2. System creates unique deployment token
3. Token linked to: client_id, site_id, expiry date
4. Token stored in database with hashed value
5. Returned as URL: https://api.yourdomain.com/deploy/TOKEN

Token Validation on Installation:
1. Agent download request with deployment token
2. Server looks up token in database
3. Verifies: not expired, linked client/site correct
4. Loads code signing auth token
5. Requests signed agent from Amidaware
6. Provides signed agent to installer
```

### Deployment Link Token Structure
```
Characteristics:
- Purpose: One-time or limited installation token
- Scope: Specific to client/site combination
- Validity: Expires after specified duration (default configurable)
- Reusability: Can be reused until expiration (no auth key needed)
- Format: URL-safe random token

Example:
https://api.yourdomain.com/deploy/5f7a9c3e2b1d4a6e8f0c2b4d6a8e0f2c

No need to share auth keys with deployment links
```

---

## 7. SECURITY CONSIDERATIONS

### Token Protection
- Store in secure configuration (environment variables, secrets vault)
- Never commit to version control
- Rotate regularly if compromise suspected
- Limit access to backend administrators
- Use HTTPS-only for all token transmissions

### Agent Security Context
- **Windows**: Runs under SYSTEM security context
- **Linux**: Typically runs as root or dedicated user
- **macOS**: Runs with appropriate permissions

### Code Signing Benefits
1. **Antivirus Whitelisting**: Signed agents can be whitelisted by security software
2. **Verification**: Recipients can verify agent authenticity
3. **Compliance**: Meets security requirements for government/enterprise deployments
4. **Trust**: Demonstrates software comes from legitimate source

### Unsigned Agent Risks
- Higher likelihood of antivirus false positives
- Difficult to whitelist with security software
- May be blocked by enterprise endpoint protection
- No verification of authenticity

### Industry Changes (May 2024)
- Amidaware moved from DigiCert to own Code Signing Root CA
- **Reason**: Hardware token/HSM requirement by DigiCert
- **Impact**: Dynamically generated installers now use Amidaware's certificate
- **Inno Setup installers**: Still signed with DigiCert OV certificate

---

## 8. ERROR HANDLING AND TROUBLESHOOTING

### Common Token-Related Errors

#### "Missing Code Signing Token"
```
Error: "Missing code signing token - 400: Bad Request"
Cause: 
- Code signing token not configured in backend
- Token has expired or been invalidated
- Request reached Amidaware without valid token

Solution:
1. Verify token is set in environment/configuration
2. Contact support@amidaware.com to verify token status
3. Request new token if needed
```

#### "Token No Longer Valid"
```
Error: "Token is no longer valid. Please read the docs for more info."
Cause:
- Amidaware invalidated token (possible compromise)
- Token was manually revoked
- Sponsorship was cancelled

Solution:
1. Check sponsorship status
2. Open support ticket to request new token
3. Provide updated API subdomain info
```

#### Unsigned Agent Downloaded
```
Scenario: Agent downloaded is unsigned (not code-signed)
Cause:
- No code signing token configured
- Token validation failed
- Fallback to unsigned agent occurred

Result:
- Agent functions normally
- Higher AV false positive rate
- Cannot be whitelisted easily
- May be blocked by enterprise security
```

### Verification Steps
1. Check token in configuration: `grep -r "code_signing" config/`
2. Verify token has valid format (should be hex or alphanumeric string)
3. Test connectivity to Amidaware: Attempt agent generation
4. Check Tactical RMM logs for error messages
5. Contact support if token appears valid but not working

---

## 9. REPOSITORY STRUCTURE (Tactical RMM Main Project)

Key files for code signing implementation:

```
amidaware/tacticalrmm/
├── api/
│   └── tacticalrmm/
│       ├── clients/
│       │   └── views.py          # GenerateAgent API endpoint
│       ├── core/
│       │   └── agent_linux.sh    # Linux installation script
│       └── settings/              # Configuration files
├── agent/                          # Go agent source code
├── scripts/                        # Utility scripts
└── docs/                           # Documentation
```

### Configuration Files to Check
- Django settings for code signing token storage
- Environment variable definitions
- Secret management configuration
- API endpoint definitions

---

## 10. KEY TAKEAWAYS

1. **Token Purpose**: Authentication for code signing agent binaries
2. **Storage**: Stored securely in Tactical RMM backend configuration
3. **Usage**: Automatically used when generating or updating agents
4. **Requirement**: Sponsorship-only feature (minimum Tier 1)
5. **Scope**: One token per self-hosted instance
6. **Multi-platform**: Single token works for Windows, Linux, macOS
7. **Security**: Critical for enterprise deployments, antivirus whitelisting
8. **Alternatives**: Community scripts available for unsigned Linux installations
9. **Support**: Amidaware provides token management and support
10. **Implementation**: Transparent to end users, critical for admins

---

## 11. NEXT STEPS FOR THIS FEATURE BRANCH

This feature branch (`claude/tactical-rmm-signing-token-01M6rUrmv2r4KUtH7AdBdUuL`) should contain:

1. **Token management API endpoints**
   - GET/POST/DELETE for token configuration
   - Token validation endpoints
   - Secure token storage implementation

2. **UI components**
   - Admin panel for token management
   - Token status display
   - Error messaging for unsigned agents

3. **Documentation**
   - Integration guide
   - API documentation
   - Configuration examples

4. **Tests**
   - Unit tests for token validation
   - Integration tests for agent generation
   - Security tests for token protection

5. **Database models** (if needed)
   - Token audit logs
   - Code signing request tracking
   - Agent signing history

---

## Resources

- **Official Docs**: https://docs.tacticalrmm.com/code_signing/
- **GitHub**: https://github.com/amidaware/tacticalrmm
- **Linux Script**: https://raw.githubusercontent.com/amidaware/tacticalrmm/develop/api/tacticalrmm/core/agent_linux.sh
- **Community Linux Script**: https://github.com/netvolt/LinuxRMM-Script
- **Support**: support@amidaware.com
- **Discord Community**: https://discord.gg/upGTkWp

