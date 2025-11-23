# Jira Import Instructions - Quick Setup Guide

## 🚀 Quick Import Methods (Fastest to Slowest)

### **Method 1: Jira CSV Importer (Recommended - 5 minutes)**

1. **Prepare your Jira project:**
   - Go to your Jira project
   - Make sure you have Admin permissions
   - Create the Epics first (see Epic list below)

2. **Create Epics in Jira:**
   - Go to **Backlog** → Click **Epic** → Create Epic
   - Create these 6 Epics:
     - `Database Schema & User Profile Management`
     - `Enhanced Story Generation Pipeline`
     - `User Feedback & Learning System`
     - `Multi-Device Streaming Experience`
     - `Trust & Safety Framework`
     - `Monetization & Launch Readiness`

3. **Import CSV:**
   - Go to **Project Settings** → **Import & Export** → **CSV Import**
   - Or use: **Issues** → **Import Issues from CSV**
   - Upload `JIRA_IMPORT_CSV.csv` (the formatted version)
   - Map columns:
     - Summary → Summary
     - Issue Type → Issue Type
     - Priority → Priority
     - Epic Link → Epic Link (map to Epic Name)
     - Description → Description
     - Acceptance Criteria → Acceptance Criteria (custom field)
   - Click **Begin Import**

**Note:** You may need to create custom fields for "Acceptance Criteria" and "Sprint" if they don't exist.

---

### **Method 2: Jira REST API (Fastest for Developers - 2 minutes)**

Use the provided Python script to bulk create tickets via API:

```bash
python jira_bulk_import.py
```

**Prerequisites:**
- Install: `pip install jira`
- Set environment variables:
  ```bash
  export JIRA_SERVER="https://your-company.atlassian.net"
  export JIRA_EMAIL="your-email@example.com"
  export JIRA_API_TOKEN="your-api-token"
  export JIRA_PROJECT_KEY="DF"  # Your project key
  ```

**Get API Token:**
1. Go to https://id.atlassian.com/manage-profile/security/api-tokens
2. Create API token
3. Use email + API token (not password) for authentication

---

### **Method 3: Jira Automation (If you have Automation enabled)**

1. Create a rule that reads from a webhook
2. Use the JSON file to send tickets via webhook
3. Configure mapping in Automation rules

---

### **Method 4: Manual Copy-Paste (Slowest but most control)**

1. Open `JIRA_TIMELINE_2_MONTHS.md`
2. For each ticket, click **Create Issue** in Jira
3. Copy-paste the details
4. Takes ~2-3 hours for all 41 tickets

---

## 📋 Pre-Import Checklist

Before importing, ensure:

- [ ] Jira project created with key "DF" (or update project key in scripts)
- [ ] Custom fields created (if needed):
  - Acceptance Criteria (Text Area)
  - Sprint (Sprint field - if using Sprint planning)
- [ ] Epics created (6 epics listed above)
- [ ] Issue types configured:
  - Story
  - Bug Fix
  - Task
- [ ] Priorities configured:
  - Critical
  - High
  - Medium
- [ ] You have Admin or Project Admin permissions

---

## 🔧 Troubleshooting

### CSV Import Issues:

**Problem:** "Epic Link not found"
- **Solution:** Create Epics first, then import. Epics must exist before linking.

**Problem:** "Custom field not found"
- **Solution:** Either create the custom field, or remove that column from CSV and add manually later.

**Problem:** "Issue Type not valid"
- **Solution:** Check your project's issue type scheme. You may need to use "Task" instead of "Story" or "Bug Fix".

### API Import Issues:

**Problem:** "Authentication failed"
- **Solution:** Use API token, not password. Check email and token are correct.

**Problem:** "Project not found"
- **Solution:** Update `JIRA_PROJECT_KEY` in script to match your project key.

---

## 📊 Post-Import Steps

After importing:

1. **Verify all tickets imported:**
   - Check ticket count matches (41 tickets)
   - Verify Epics are linked correctly

2. **Set up dependencies:**
   - Go to each ticket
   - Add "Blocks" or "Depends on" links based on Dependencies column
   - Or use bulk edit to add links

3. **Create Sprints:**
   - Create 8 sprints (Week 1, Week 2, etc.)
   - Assign tickets to sprints based on "Sprint" column

4. **Assign initial estimates:**
   - Add story points or time estimates
   - Suggested: Critical = 8pts, High = 5pts, Medium = 3pts

5. **Set up workflow:**
   - Configure board columns
   - Set up automation rules if needed

---

## 🎯 Quick Start Commands

### For CSV Import:
```bash
# 1. Open Jira
# 2. Go to Issues → Import Issues from CSV
# 3. Upload JIRA_IMPORT_CSV.csv
# 4. Map columns and import
```

### For API Import:
```bash
# 1. Install dependencies
pip install jira python-dotenv

# 2. Set up .env file
echo "JIRA_SERVER=https://your-company.atlassian.net" > .env
echo "JIRA_EMAIL=your-email@example.com" >> .env
echo "JIRA_API_TOKEN=your-token" >> .env
echo "JIRA_PROJECT_KEY=DF" >> .env

# 3. Run script
python jira_bulk_import.py
```

---

## 📝 Custom Field Setup

If you need to create custom fields:

1. Go to **Settings** → **Issues** → **Custom Fields**
2. Click **Create Custom Field**
3. For "Acceptance Criteria":
   - Type: **Text Area (multi-line)**
   - Name: **Acceptance Criteria**
   - Add to screens as needed
4. For "Sprint" (if not using Jira Software):
   - Type: **Text Field**
   - Name: **Sprint**

---

## ⚡ Fastest Method Summary

**For non-technical users:** Use Method 1 (CSV Import) - takes ~5 minutes after Epics are created.

**For developers:** Use Method 2 (API Script) - takes ~2 minutes, fully automated.

**For maximum control:** Use Method 4 (Manual) - takes 2-3 hours but you can customize everything.

