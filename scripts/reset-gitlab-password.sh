#!/bin/bash

# Script to reset GitLab root password
# Usage: ./reset-gitlab-password.sh <new_password>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if password argument is provided
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No password provided${NC}"
    echo "Usage: $0 <new_password>"
    echo "Example: $0 MyNewSecurePassword123!"
    exit 1
fi

NEW_PASSWORD="$1"

# Validate password strength (at least 8 characters)
if [ ${#NEW_PASSWORD} -lt 8 ]; then
    echo -e "${RED}Error: Password must be at least 8 characters long${NC}"
    exit 1
fi

echo -e "${YELLOW}Checking GitLab status...${NC}"

# Get the GitLab pod name
GITLAB_POD=$(kubectl get pods -n gitlab -l app=gitlab -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$GITLAB_POD" ]; then
    echo -e "${RED}Error: No GitLab pod found. Is GitLab deployed?${NC}"
    echo "Run: kubectl get pods -n gitlab"
    exit 1
fi

# Check if pod is ready
POD_READY=$(kubectl get pod "$GITLAB_POD" -n gitlab -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null || echo "false")

if [ "$POD_READY" != "true" ]; then
    echo -e "${RED}Error: GitLab pod is not ready yet${NC}"
    echo "Current pod status:"
    kubectl get pod "$GITLAB_POD" -n gitlab
    echo ""
    echo "Wait for the pod to be ready (1/1) and try again."
    exit 1
fi

echo -e "${GREEN}Found GitLab pod: ${GITLAB_POD} (Ready)${NC}"

# Check node memory pressure
echo -e "${YELLOW}Checking node memory status...${NC}"
MEMORY_PRESSURE=$(kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="MemoryPressure")].status}' | grep -o "True" | wc -l || echo "0")

if [ "$MEMORY_PRESSURE" -gt 0 ]; then
    echo -e "${RED}Warning: Node has memory pressure. Password reset may fail.${NC}"
    echo "Consider waiting for memory pressure to clear or use the GitLab UI instead."
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Use a simpler, memory-efficient approach
RAILS_COMMAND="user = User.find_by_username('root'); user.password = user.password_confirmation = '${NEW_PASSWORD}'; user.save!"

echo -e "${YELLOW}Resetting GitLab root password...${NC}"
echo "This may take 30-60 seconds..."

# Execute the password reset command with timeout and resource limits
# Use gtimeout on macOS if available, fallback to kubectl without timeout
if command -v gtimeout >/dev/null 2>&1; then
    gtimeout 120s kubectl exec -n gitlab "$GITLAB_POD" -- gitlab-rails runner "$RAILS_COMMAND"
elif command -v timeout >/dev/null 2>&1; then
    timeout 120s kubectl exec -n gitlab "$GITLAB_POD" -- gitlab-rails runner "$RAILS_COMMAND"
else
    # No timeout available, run directly (macOS default)
    kubectl exec -n gitlab "$GITLAB_POD" -- gitlab-rails runner "$RAILS_COMMAND"
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Password successfully reset!${NC}"
    echo ""
    echo "You can now login to GitLab with:"
    echo "  Username: root"
    echo "  Password: ${NEW_PASSWORD}"
    echo ""
    echo "To access GitLab UI, run:"
    echo "  kubectl port-forward -n gitlab svc/gitlab 8181:80"
    echo "Then open: http://localhost:8181"
elif [ $? -eq 124 ]; then
    echo -e "${RED}✗ Password reset timed out${NC}"
    echo "This may happen under memory pressure. Try again later or use GitLab UI."
    exit 1
else
    echo -e "${RED}✗ Failed to reset password${NC}"
    echo "Check GitLab logs: kubectl logs -f deployment/gitlab -n gitlab"
    exit 1
fi