# Code Signing Tokens - Implementation Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Admin/Web UI                                  │
│  - Generate Agent Link                                          │
│  - Manage Deployment Links                                      │
│  - View Token Status                                            │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│                   Django Backend API                             │
│  - Clients app (views.py)                                       │
│    - GenerateAgent endpoint                                     │
│    - DeploymentLink endpoints                                   │
│  - Core app                                                     │
│    - Token configuration                                        │
│    - Code signing logic                                         │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│            Token Storage & Management                            │
│  - Django Settings (environment variables)                      │
│  - Database (encrypted)                                         │
│  - Secrets vault integration                                    │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│         Amidaware Code Signing Servers                          │
│  https://codesigning.amidaware.com/api/v1/sign                │
│  - Validates token                                              │
│  - Returns signed or unsigned agent                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Checklist

### 1. Configuration Management

**File**: `tacticalrmm/settings/base.py` or `.env`

```python
# Token Configuration
CODE_SIGNING_TOKEN = os.environ.get('CODE_SIGNING_TOKEN', '')
CODE_SIGNING_SERVER = 'https://codesigning.amidaware.com/api/v1/sign'
AGENT_SIGNING_ENABLED = bool(CODE_SIGNING_TOKEN)
```

### 2. Token Storage

**Database Model** (if audit logging needed):

```python
# models.py
class CodeSigningToken(models.Model):
    token = models.CharField(max_length=255, unique=True)
    is_active = models.BooleanField(default=True)
    api_subdomain = models.CharField(max_length=255)
    created_date = models.DateTimeField(auto_now_add=True)
    updated_date = models.DateTimeField(auto_now=True)
    last_used = models.DateTimeField(null=True, blank=True)
    valid_until = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        verbose_name = "Code Signing Token"
        verbose_name_plural = "Code Signing Tokens"
    
    def __str__(self):
        return f"Token for {self.api_subdomain}"
    
    def is_valid(self):
        return self.is_active and (
            self.valid_until is None or 
            self.valid_until > timezone.now()
        )
```

### 3. Token Validation Service

**File**: `tacticalrmm/core/signing_service.py`

```python
import requests
import logging
from django.conf import settings
from datetime import datetime

logger = logging.getLogger(__name__)

class CodeSigningService:
    """Handles communication with Amidaware code signing servers"""
    
    def __init__(self):
        self.token = settings.CODE_SIGNING_TOKEN
        self.server_url = settings.CODE_SIGNING_SERVER
    
    def is_token_configured(self):
        """Check if code signing token is configured"""
        return bool(self.token)
    
    def sign_agent(self, agent_binary, agent_type='windows'):
        """
        Send agent binary to be signed by Amidaware
        
        Args:
            agent_binary: Binary content of unsigned agent
            agent_type: 'windows', 'linux', or 'macos'
        
        Returns:
            Signed agent binary or unsigned agent if signing fails
        """
        if not self.is_token_configured():
            logger.warning("Code signing token not configured, returning unsigned agent")
            return agent_binary
        
        try:
            headers = {
                'Authorization': f'Bearer {self.token}',
                'Content-Type': 'application/octet-stream',
                'X-Agent-Type': agent_type
            }
            
            response = requests.post(
                self.server_url,
                headers=headers,
                data=agent_binary,
                timeout=30
            )
            
            if response.status_code == 200:
                logger.info(f"Successfully signed {agent_type} agent")
                return response.content
            else:
                logger.warning(
                    f"Code signing failed ({response.status_code}), "
                    f"returning unsigned agent"
                )
                return agent_binary
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Error contacting signing server: {str(e)}")
            return agent_binary
    
    def validate_token(self):
        """Validate token with Amidaware servers"""
        if not self.is_token_configured():
            return False
        
        try:
            headers = {'Authorization': f'Bearer {self.token}'}
            response = requests.get(
                f"{self.server_url}/validate",
                headers=headers,
                timeout=10
            )
            return response.status_code == 200
        except:
            return False
```

### 4. API Endpoint Implementation

**File**: `tacticalrmm/clients/views.py`

```python
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from tacticalrmm.core.signing_service import CodeSigningService
from django.http import FileResponse
import logging

logger = logging.getLogger(__name__)

class GenerateAgent(APIView):
    """Generate agent installer (Windows, Linux, macOS)"""
    permission_classes = (AllowAny,)
    
    def post(self, request):
        """Generate and optionally sign agent"""
        try:
            client_id = request.data.get('client_id')
            site_id = request.data.get('site_id')
            agent_type = request.data.get('agent_type')
            arch = request.data.get('arch', '64')
            os_type = request.data.get('os_type', 'windows')
            
            # Validate request parameters
            if not all([client_id, site_id, agent_type]):
                return Response(
                    {'error': 'Missing required parameters'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Build agent binary
            agent_binary = self._build_agent_binary(
                client_id, site_id, agent_type, arch, os_type
            )
            
            # Sign agent if token is configured
            signing_service = CodeSigningService()
            signed_agent = signing_service.sign_agent(
                agent_binary, 
                agent_type=os_type
            )
            
            # Return agent binary
            filename = self._generate_filename(client_id, site_id, os_type, arch)
            return FileResponse(
                signed_agent,
                as_attachment=True,
                filename=filename
            )
            
        except Exception as e:
            logger.error(f"Error generating agent: {str(e)}")
            return Response(
                {'error': 'Failed to generate agent'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    def _build_agent_binary(self, client_id, site_id, agent_type, arch, os_type):
        """Build unsigned agent binary"""
        # Implementation depends on agent binary location
        # Could be stored files or dynamically generated
        pass
    
    def _generate_filename(self, client_id, site_id, os_type, arch):
        """Generate appropriate filename based on OS type"""
        if os_type == 'windows':
            return f"tacticalagent-{client_id}-{site_id}-windows-{arch}.exe"
        elif os_type == 'linux':
            return f"tacticalagent-{client_id}-{site_id}-linux-{arch}.sh"
        else:  # macos
            return f"tacticalagent-{client_id}-{site_id}-macos-{arch}.pkg"


class TokenStatus(APIView):
    """Check code signing token status"""
    permission_classes = (IsAuthenticated, IsAdminUser)
    
    def get(self, request):
        """Get token configuration status"""
        signing_service = CodeSigningService()
        
        return Response({
            'configured': signing_service.is_token_configured(),
            'valid': signing_service.validate_token(),
            'signing_enabled': getattr(settings, 'AGENT_SIGNING_ENABLED', False)
        })


class ConfigureToken(APIView):
    """Configure code signing token"""
    permission_classes = (IsAuthenticated, IsAdminUser)
    
    def post(self, request):
        """Update code signing token"""
        new_token = request.data.get('token')
        
        if not new_token:
            return Response(
                {'error': 'Token required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            # Store token (implementation depends on storage method)
            # Option 1: Environment variable (requires restart)
            # Option 2: Database model
            # Option 3: Secrets manager
            
            # Validate token
            signing_service = CodeSigningService()
            if not signing_service.validate_token():
                return Response(
                    {'error': 'Token validation failed'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            return Response({'status': 'Token configured successfully'})
            
        except Exception as e:
            logger.error(f"Error configuring token: {str(e)}")
            return Response(
                {'error': 'Failed to configure token'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
```

### 5. URL Configuration

**File**: `tacticalrmm/clients/urls.py`

```python
from django.urls import path
from . import views

urlpatterns = [
    path('api/agents/generate', views.GenerateAgent.as_view(), name='generate-agent'),
    path('api/agents/token-status', views.TokenStatus.as_view(), name='token-status'),
    path('api/agents/configure-token', views.ConfigureToken.as_view(), name='configure-token'),
]
```

### 6. Deployment Link Token Model

**File**: `tacticalrmm/core/models.py`

```python
import secrets
from django.db import models
from django.utils import timezone
from datetime import timedelta

class DeploymentLink(models.Model):
    AGENT_TYPE_CHOICES = [
        ('windows', 'Windows'),
        ('linux', 'Linux'),
        ('macos', 'macOS'),
    ]
    
    client = models.ForeignKey('clients.Client', on_delete=models.CASCADE)
    site = models.ForeignKey('clients.Site', on_delete=models.CASCADE)
    token = models.CharField(max_length=128, unique=True, default=secrets.token_urlsafe)
    agent_type = models.CharField(max_length=20, choices=AGENT_TYPE_CHOICES)
    server_or_workstation = models.CharField(max_length=20)
    architecture = models.CharField(max_length=10, choices=[('64', '64-bit'), ('32', '32-bit')])
    created_date = models.DateTimeField(auto_now_add=True)
    expiry_date = models.DateTimeField()
    is_active = models.BooleanField(default=True)
    
    class Meta:
        verbose_name = "Deployment Link"
        verbose_name_plural = "Deployment Links"
    
    def is_expired(self):
        return timezone.now() > self.expiry_date
    
    def is_valid(self):
        return self.is_active and not self.is_expired()
    
    def __str__(self):
        return f"{self.client.name} - {self.agent_type}"


class DeploymentLinkLog(models.Model):
    """Audit log for deployment link usage"""
    deployment_link = models.ForeignKey(DeploymentLink, on_delete=models.CASCADE)
    download_timestamp = models.DateTimeField(auto_now_add=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=255, null=True, blank=True)
    signed = models.BooleanField(default=True)  # Whether signed or unsigned agent
    
    class Meta:
        verbose_name = "Deployment Link Log"
        verbose_name_plural = "Deployment Link Logs"
```

---

## Testing Strategy

### Unit Tests

```python
# tests/test_signing_service.py
from django.test import TestCase
from tacticalrmm.core.signing_service import CodeSigningService

class CodeSigningServiceTests(TestCase):
    
    def test_token_configured(self):
        service = CodeSigningService()
        # Test with and without token
    
    def test_sign_agent_success(self):
        # Mock response from signing server
        pass
    
    def test_sign_agent_failure_fallback(self):
        # Test fallback to unsigned when signing fails
        pass
    
    def test_token_validation(self):
        # Test token validation endpoint
        pass
```

### Integration Tests

```python
# tests/test_agent_generation.py
from django.test import TestCase, Client

class AgentGenerationTests(TestCase):
    
    def test_generate_signed_windows_agent(self):
        # Test Windows agent generation
        pass
    
    def test_generate_linux_agent_with_token(self):
        # Test Linux agent with code signing token
        pass
    
    def test_deployment_link_creation(self):
        # Test deployment link token generation
        pass
    
    def test_deployment_link_expiry(self):
        # Test expired link handling
        pass
```

---

## Environment Configuration

### `.env` Example
```bash
# Code Signing Configuration
CODE_SIGNING_TOKEN=your_token_here_from_amidaware
CODE_SIGNING_SERVER=https://codesigning.amidaware.com/api/v1/sign
AGENT_SIGNING_ENABLED=True
```

### Docker Compose
```yaml
services:
  tacticalrmm:
    environment:
      - CODE_SIGNING_TOKEN=${CODE_SIGNING_TOKEN}
      - CODE_SIGNING_SERVER=https://codesigning.amidaware.com/api/v1/sign
      - AGENT_SIGNING_ENABLED=True
```

---

## Deployment Considerations

1. **Token Security**
   - Never log the actual token
   - Use secrets management system
   - Rotate regularly
   - Monitor access logs

2. **Error Handling**
   - Gracefully fallback to unsigned agents
   - Log all signing failures
   - Alert admins on persistent failures
   - Provide user-friendly error messages

3. **Performance**
   - Cache signing results where appropriate
   - Implement request timeout (30 seconds)
   - Consider async signing for large deployments
   - Monitor Amidaware server response times

4. **Monitoring**
   - Track signing success rate
   - Monitor API response times
   - Alert on token validation failures
   - Log deployment link usage

---

## References

- Amidaware Code Signing API: https://docs.tacticalrmm.com/code_signing/
- Django REST Framework: https://www.django-rest-framework.org/
- Python Requests: https://requests.readthedocs.io/

