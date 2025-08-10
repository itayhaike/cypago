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

echo -e "${YELLOW}Resetting GitLab root password...${NC}"

# Get the GitLab pod name
GITLAB_POD=$(kubectl get pods -n gitlab -l app=gitlab -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$GITLAB_POD" ]; then
    echo -e "${RED}Error: No GitLab pod found. Is GitLab deployed?${NC}"
    echo "Run: kubectl get pods -n gitlab"
    exit 1
fi

echo -e "${GREEN}Found GitLab pod: ${GITLAB_POD}${NC}"

# Create a temporary file with the Rails commands
RAILS_COMMANDS=$(cat <<EOF
user = User.find_by(username: 'root')
if user
  user.password = '${NEW_PASSWORD}'
  user.password_confirmation = '${NEW_PASSWORD}'
  user.skip_reconfirmation!
  if user.save!
    puts 'Password successfully updated!'
  else
    puts 'Failed to update password: ' + user.errors.full_messages.join(', ')
    exit 1
  end
else
  puts 'Root user not found!'
  exit 1
end
EOF
)

# Execute the password reset command in the GitLab pod
echo -e "${YELLOW}Executing password reset in pod...${NC}"

kubectl exec -n gitlab "${GITLAB_POD}" -- gitlab-rails runner "${RAILS_COMMANDS}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Password successfully reset!${NC}"
    echo ""
    echo "You can now login to GitLab with:"
    echo "  Username: root"
    echo "  Password: ${NEW_PASSWORD}"
    echo ""
    echo "To access GitLab UI, run:"
    echo "  kubectl port-forward -n gitlab svc/gitlab 8080:80"
    echo "Then open: http://localhost:8080"
else
    echo -e "${RED}✗ Failed to reset password${NC}"
    exit 1
fi

