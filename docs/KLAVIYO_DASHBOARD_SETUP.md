# Klaviyo Dashboard Setup Guide for Dream Flow

**Complete Setup Checklist** - Follow this guide to configure your Klaviyo dashboard to work perfectly with Dream Flow's backend integration.

---

## 📋 Quick Setup Checklist

- [ ] **Step 1:** Verify API Key Configuration
- [ ] **Step 2:** Create Segments
- [ ] **Step 3:** Set Up Flows (Email Automation)
- [ ] **Step 4:** Configure Lists
- [ ] **Step 5:** Create Email Templates
- [ ] **Step 6:** Set Up Metrics Dashboard
- [ ] **Step 7:** Test Integration

**Estimated Time:** 30-45 minutes

---

## Step 1: Verify API Key Configuration ✅

### What You Need:

Your backend is already configured to send data to Klaviyo using your Private API Key.

### Verify in Klaviyo:

1. Log in to [Klaviyo Dashboard](https://www.klaviyo.com/login)
2. Go to **Settings** → **API Keys**
3. Confirm you see your **Private API Key** starting with `pk_`
4. This key should match what's in your `.env` file: `KLAVIYO_API_KEY`

✅ **Done!** Your backend is already sending data. Now let's set up the dashboard to use it.

---

## Step 2: Create Segments 🎯

Segments let you target specific user groups. Your backend sends these profile properties that you can use:

### Profile Properties Available:

- `subscription_tier` (free, premium, family)
- `story_preferences` (array of themes)
- `total_stories` (number)
- `current_streak` (number)
- `family_mode_enabled` (true/false)

### Recommended Segments to Create:

#### 2.1 **High Engagement Users**

**Purpose:** Users actively using the app

1. Go to **Audience** → **Segments**
2. Click **Create Segment**
3. Name: `High Engagement Users`
4. Click **"Select a condition"** dropdown
5. Choose **"Properties about someone"**
6. Add first condition:
   - Search for property: `total_stories`
   - Select operator: `is greater than`
   - Enter value: `10`
7. Click **"AND"** to add another condition
8. Choose **"Properties about someone"** again
9. Add second condition:
   - Search for property: `current_streak`
   - Select operator: `is greater than`
   - Enter value: `3`
10. Click **Create Segment**

**Note:** If `total_stories` or `current_streak` don't appear, you need to create a test user first and generate stories. Klaviyo only shows properties that have been sent at least once.

#### 2.2 **Churn Risk Users**

**Purpose:** Users who stopped using the app

1. Click **Create Segment**
2. Name: `Churn Risk - Inactive Users`
3. Click **"Select a condition"** dropdown
4. Choose **"Properties about someone"**
5. Add first condition:
   - Property: `total_stories`
   - Operator: `is greater than`
   - Value: `1` (has used app before)
6. Click **"AND"** to add another condition
7. Choose **"What someone has done (or not done)"**
8. Select: `Story Generated`
9. Change to: `zero times`
10. Set time range: `in the last 14 days`
11. Click **Create Segment**

#### 2.3 **Free Tier - Upgrade Candidates**

**Purpose:** Free users who love the app

1. Click **Create Segment**
2. Name: `Free Tier - Ready to Upgrade`
3. Click **"Select a condition"** dropdown
4. Choose **"Properties about someone"**
5. Add conditions one by one (click "AND" between each):
   - First: `subscription_tier` → `equals` → `free`
   - Second: `total_stories` → `is greater than` → `15`
   - Third: `current_streak` → `is greater than` → `5`
6. Click **Create Segment**

#### 2.4 **Premium Subscribers**

**Purpose:** Paying customers

1. Click **Create Segment**
2. Name: `Premium Subscribers`
3. Click **"Select a condition"** dropdown
4. Choose **"Properties about someone"**
5. Add first condition:
   - Property: `subscription_tier`
   - Operator: `equals`
   - Value: `premium`
6. Click **"OR"** (not AND) to add another condition
7. Choose **"Properties about someone"**
8. Add second condition:
   - Property: `subscription_tier`
   - Operator: `equals`
   - Value: `family`
9. Click **Create Segment**

#### 2.5 **Family Mode Users**

**Purpose:** Multi-child families

1. Click **Create Segment**
2. Name: `Family Mode Users`
3. Click **"Select a condition"** dropdown
4. Choose **"Properties about someone"**
5. Add condition:
   - Property: `family_mode_enabled`
   - Operator: `equals`
   - Value: `true`
6. Click **Create Segment**

---

## Step 3: Set Up Flows (Email Automation) 📧

Flows automatically send emails based on events your backend tracks.

### Events Your Backend Sends:

1. ✅ **Signed Up** - User creates account
2. ✅ **Story Generated** - User creates a story
3. ✅ **Subscription Created** - User upgrades
4. ✅ **Subscription Cancelled** - User downgrades
5. ✅ **Profile Updated** - User changes preferences
6. ✅ **Story Downloaded** - User saves a story
7. ✅ **Streak Maintained** - User maintains daily streak

### Flows to Create:

#### 3.1 **Welcome Flow** (You already have this! ✅)

**Trigger:** `Signed Up` event

**Keep your existing flow!** Just verify:

- ✅ Status: Live
- ✅ Trigger metric: "Signed Up"
- ✅ Welcome email sends within 5 minutes

#### 3.2 **First Story Celebration Flow**

**Purpose:** Celebrate user's first story

1. Go to **Flows** → **Create Flow**
2. Choose **Create From Scratch**
3. Name: `First Story Celebration`
4. **Trigger:**
   - Select **Metric**
   - Choose `Story Generated`
   - Add filter: `total_stories` → `less than` → `2`
5. **Add Action:** Send Email
   - Subject: `🎉 Your first Dream Flow story is magical!`
   - Preview: `Thanks for creating your first bedtime story...`
6. Set to **Live**

#### 3.3 **Re-engagement Flow**

**Purpose:** Win back inactive users

1. Create Flow
2. Name: `Re-engagement - Win Back`
3. **Trigger:**
   - Select **Segment**
   - Choose `Churn Risk - Inactive Users`
4. **Wait:** 1 day (give them a chance to come back naturally)
5. **Add Action:** Send Email
   - Subject: `We miss you! Your child's favorite stories are waiting 🌙`
   - Preview: `It's been a while since your last story...`
6. **Add Time Delay:** 3 days
7. **Add Conditional Split:**
   - If `Story Generated` in last 3 days → Exit flow
   - Else → Continue
8. **Add Action:** Send Email (second reminder)
   - Subject: `Last chance: Come back to Dream Flow tonight`
9. Set to **Live**

#### 3.4 **Upgrade Nudge Flow**

**Purpose:** Convert free users to paid

1. Create Flow
2. Name: `Upgrade Nudge - Free to Premium`
3. **Trigger:**
   - Segment: `Free Tier - Ready to Upgrade`
4. **Add Action:** Send Email
   - Subject: `You're loving Dream Flow! Unlock unlimited stories ✨`
   - Preview: `You've created 15+ stories. Upgrade to premium for...`
   - Include benefits: Unlimited stories, voice selection, download stories
5. Set to **Live**

#### 3.5 **Streak Celebration Flow**

**Purpose:** Reward consistent users

1. Create Flow
2. Name: `Streak Milestone Celebration`
3. **Trigger:**
   - Metric: `Story Generated`
   - Add filter: `current_streak` → `equals` → `7` OR `14` OR `30`
4. **Add Action:** Send Email
   - Subject: `🔥 Amazing! You've maintained a {current_streak}-day streak!`
   - Preview: `Consistency is key to great bedtime routines...`
5. Set to **Live**

#### 3.6 **Subscription Cancellation Recovery**

**Purpose:** Understand why and offer help

1. Create Flow
2. Name: `Cancellation Feedback`
3. **Trigger:**
   - Metric: `Subscription Cancelled`
4. **Add Action:** Send Email
   - Subject: `We're sorry to see you go - Can we help?`
   - Preview: `Your subscription has been cancelled. Before you go...`
   - Include feedback survey link
5. Set to **Live**

---

## Step 4: Configure Lists 📋

Lists are static groups you can manually add people to or sync from segments.

### Recommended Lists:

#### 4.1 **Newsletter Subscribers**

1. Go to **Audience** → **Lists**
2. Create List
3. Name: `Dream Flow Newsletter`
4. Use for: Weekly content, updates, tips

#### 4.2 **Beta Testers**

1. Create List
2. Name: `Beta Testers`
3. Use for: Early access to features

#### 4.3 **VIP Users**

1. Create List
2. Name: `VIP Users`
3. Manually add high-value customers

---

## Step 5: Create Email Templates 📝

### Template Structure:

All your emails should include:

- Dream Flow branding/logo
- Clear call-to-action button
- Unsubscribe link (required)
- Social media links

### Key Templates Needed:

#### 5.1 **Welcome Email**

**When:** Signed Up event
**Content:**

```
Subject: Welcome to Dream Flow! 🌙

Hi {first_name|there},

Welcome to Dream Flow! We're so excited to help you create magical
bedtime stories for your family.

Here's what you can do right now:
→ Create your first story in 30 seconds
→ Explore our story themes
→ Set up your child's preferences

[CREATE YOUR FIRST STORY]

Sweet dreams,
The Dream Flow Team
```

#### 5.2 **Re-engagement Email**

**When:** User inactive 14 days
**Content:**

```
Subject: We miss you! Your child's favorite stories are waiting 🌙

Hi {first_name},

It's been {days_since_last_story} days since your last story, and
we noticed you used to love {favorite_theme} stories!

Special just for you:
✨ New {favorite_theme} story templates added
✨ Your streak can start fresh tonight
✨ Only takes 30 seconds to create

[CREATE A STORY TONIGHT]

We'd love to have you back!
```

#### 5.3 **Upgrade Nudge Email**

**When:** Free user with 15+ stories
**Content:**

```
Subject: You're loving Dream Flow! Unlock unlimited stories ✨

Hi {first_name},

Wow! You've created {total_stories} stories. Your family clearly
loves Dream Flow!

Here's what you're missing with Premium:
✅ Unlimited stories (vs 3/day on free)
✅ Download stories to listen offline
✅ Advanced voice options
✅ Priority support
✅ Family mode for multiple children

[UPGRADE TO PREMIUM - $9.99/mo]

7-day money-back guarantee!
```

### How to Create Templates:

1. Go to **Content** → **Email Templates**
2. Click **Create Template**
3. Choose **Drag-and-Drop Editor** or **HTML Editor**
4. Build your template with these sections:
   - Header with logo
   - Main content area
   - Call-to-action button
   - Footer with unsubscribe
5. Save with descriptive name
6. Use template in flows by selecting it when adding email actions

---

## Step 6: Set Up Metrics Dashboard 📊

### What to Monitor:

#### 6.1 **Create a Custom Dashboard**

1. Go to **Analytics** → **Overview**
2. Click **Create Dashboard**
3. Name: `Dream Flow - Core Metrics`

#### 6.2 **Add These Metrics:**

**Metric 1: Story Generation Rate**

- Metric: `Story Generated`
- View: Event count over time (last 30 days)
- Chart type: Line chart

**Metric 2: New Signups**

- Metric: `Signed Up`
- View: Event count over time (last 30 days)
- Chart type: Bar chart

**Metric 3: Subscription Conversions**

- Metric: `Subscription Created`
- View: Event count over time
- Filter: Where `subscription_tier` is not `free`

**Metric 4: Churn Events**

- Metric: `Subscription Cancelled`
- View: Event count over time
- Alert: Email you if count > 5 in a day

**Metric 5: User Engagement**

- Metric: `Story Generated`
- View: Unique users (not total events)
- Shows: Active user count

#### 6.3 **Set Up Reports**

1. Go to **Analytics** → **Custom Reports**
2. Create report: `Weekly Engagement Summary`
3. Metrics to include:
   - New signups
   - Stories generated
   - Active users
   - Conversion rate (signups → paying)
4. Schedule: Email yourself every Monday at 9am

---

## Step 7: Test Integration 🧪

### Testing Checklist:

#### 7.1 **Test Event Tracking**

1. Create a test user in your app (sign up with a test email)
2. In Klaviyo, go to **Audience** → **Profiles**
3. Search for your test email
4. Verify profile was created
5. Check that `Signed Up` event appears in activity feed

#### 7.2 **Test Flow Triggers**

1. Generate a story with your test user
2. Wait 5 minutes
3. Check test email inbox for welcome email
4. Check Klaviyo flow analytics to see if message was sent

#### 7.3 **Test Segment Membership**

1. Go to your test profile
2. Check which segments they're in
3. Should be in "Free Tier" segments

#### 7.4 **Verify Profile Properties**

1. In test profile, click **Properties**
2. Verify you see:
   - ✅ `subscription_tier`: "free"
   - ✅ `total_stories`: 1 (or more)
   - ✅ `story_preferences`: [...themes...]
   - ✅ `current_streak`: 1
   - ✅ `family_mode_enabled`: true/false

---

## 🎯 Advanced Setup (Optional)

### A/B Testing Flows

1. In any flow, select an email
2. Click **A/B Test**
3. Test different:
   - Subject lines
   - Send times
   - Email content
4. Klaviyo will auto-optimize

### SMS Integration (If you add SMS)

1. Go to **SMS** → **Settings**
2. Purchase phone number
3. Create SMS flows similar to email flows
4. Requires updating backend to send phone numbers

### Push Notifications (Future)

- Klaviyo supports push for mobile apps
- Requires SDK integration in Flutter app
- Can trigger based on same events

---

## 📱 Quick Reference: Events Your Backend Tracks

| Event Name               | When It Fires         | Key Properties                                                 |
| ------------------------ | --------------------- | -------------------------------------------------------------- |
| `Signed Up`              | User creates account  | `signup_method`                                                |
| `Story Generated`        | User creates story    | `theme`, `story_length`, `num_scenes`, `user_mood`             |
| `Subscription Created`   | User upgrades         | `subscription_tier`, `previous_tier`, `stripe_subscription_id` |
| `Subscription Cancelled` | User cancels          | `subscription_tier`, `cancel_at_period_end`                    |
| `Profile Updated`        | User changes settings | `updated_fields`                                               |
| `Story Downloaded`       | User saves story      | `story_id`, `format`                                           |
| `Streak Maintained`      | User maintains streak | `streak_count`                                                 |

---

## 🎨 Profile Properties Your Backend Syncs

| Property              | Type    | Example                     | Use For                     |
| --------------------- | ------- | --------------------------- | --------------------------- |
| `subscription_tier`   | String  | "free", "premium", "family" | Segmentation, upgrade flows |
| `story_preferences`   | Array   | ["Ocean", "Animals"]        | Personalization             |
| `total_stories`       | Number  | 42                          | Engagement tracking         |
| `current_streak`      | Number  | 7                           | Gamification, retention     |
| `family_mode_enabled` | Boolean | true                        | Family-specific flows       |
| `first_name`          | String  | "Jane"                      | Personalization             |
| `last_name`           | String  | "Doe"                       | Personalization             |

---

## 🚨 Troubleshooting

### Issue: "No events showing up"

**Check:**

1. Backend is running with `KLAVIYO_ENABLED=true`
2. `KLAVIYO_API_KEY` is correct
3. Backend logs show: `"Klaviyo service initialized successfully"`
4. Wait 2-3 minutes for events to sync

### Issue: "Profile created but no custom properties"

**Fix:**

- Your backend syncs properties after events
- Generate a story with test user
- Properties should appear within 1-2 minutes

### Issue: "Flow not triggering"

**Check:**

1. Flow is set to **Live** (not Draft)
2. User matches flow filters/conditions
3. User hasn't already been through flow recently
4. Check flow analytics for skipped messages

### Issue: "Segments are empty"

**Fix:**

- Segments need data to populate
- Create test users and generate stories
- Wait 5-10 minutes for segments to update
- Check segment conditions are correct

---

## ✅ Setup Complete Checklist

Before going live, verify:

- [x] API key configured and working
- [x] At least 3 segments created (High Engagement, Churn Risk, Premium)
- [x] Welcome flow active and tested
- [x] Re-engagement flow created
- [x] Email templates branded with Dream Flow
- [x] Metrics dashboard set up
- [x] Test user created and verified in Klaviyo
- [x] Test email received from welcome flow
- [x] Profile properties visible in test profile

---

## 📞 Need Help?

**Klaviyo Resources:**

- [Klaviyo Help Center](https://help.klaviyo.com/)
- [Community Forum](https://community.klaviyo.com/)
- [Developer Docs](https://developers.klaviyo.com/)

**Dream Flow Integration:**

- Check `docs/KLAVIYO_INTEGRATION.md` for technical details
- Review `docs/IMPLEMENTATION_SUMMARY_KLAVIYO.md` for architecture
- Test with demo endpoints: `/api/v1/demo/klaviyo-integration`

---

## 🎉 You're All Set!

Your Klaviyo dashboard is now configured to work perfectly with Dream Flow's backend integration.

**Next Steps:**

1. Monitor your metrics dashboard daily
2. Review flow performance weekly
3. A/B test email content monthly
4. Adjust segments based on user behavior

**Expected Results:**

- 📈 Higher user engagement (story generation rate)
- 💰 Increased conversions (free → premium)
- ❤️ Reduced churn (re-engagement flows)
- 📊 Better insights (analytics dashboard)

Good luck! 🚀
