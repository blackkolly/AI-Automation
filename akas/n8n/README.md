# n8n Demo Workflow Setup

# This creates visible workflows that demonstrate integration

# 1. Document Processing Notification Workflow

# Webhook: http://localhost:5678/webhook/document-processed

# Purpose: Send email/slack notification when documents are uploaded

# 2. Query Performance Monitor Workflow

# Webhook: http://localhost:5678/webhook/query-processed

# Purpose: Log slow queries and send alerts

# 3. User Feedback Processing Workflow

# Webhook: http://localhost:5678/webhook/user-feedback

# Purpose: Process user ratings and comments

## How to Test n8n Integration Visibility:

1. **Start Enhanced AKAS:**

   ```bash
   docker-compose -f docker-compose-test-enhanced.yml up --build
   ```

2. **Access n8n Interface:**

   - URL: http://localhost:5678
   - Login: admin/password
   - Create workflows with webhook triggers

3. **See Integration in Action:**

   - Upload documents → Check n8n workflow tab for trigger status
   - Make queries → See workflow results in real-time
   - View workflow history and logs

4. **Test URLs:**
   - Frontend with n8n tab: http://localhost:8501
   - n8n status API: http://localhost:8000/v2/n8n-status/
   - Manual workflow trigger: http://localhost:8000/v2/trigger-workflow/
   - Health with n8n status: http://localhost:8000/v2/health/

## Visible Differences With n8n:

**WITHOUT n8n:**

- Document upload just returns: {"results": [...]}
- No workflow automation
- No external integrations

**WITH n8n:**

- Document upload returns: {"results": [...], "n8n_workflow": {"status": "triggered"}}
- Dedicated n8n management tab in frontend
- Real-time workflow status in sidebar
- Manual workflow testing interface
- Workflow history and monitoring
- External system integration capabilities

## Example n8n Use Cases:

- Email notifications for new documents
- Slack alerts for system issues
- Database logging of user activities
- Integration with external APIs
- Automated reports and analytics
- Custom business logic processing
