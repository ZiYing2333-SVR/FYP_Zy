# Deploy Backend to Render - Complete Guide

## Why Render?
- ✅ **Free tier**: 750 hours/month (enough for personal use)
- ✅ **Simple**: Auto-detects Python, auto-deploys from GitHub
- ✅ **Good UI**: Easy to manage and monitor
- ✅ **Note**: Auto-sleeps after 15 min inactivity (slower first request)

---

## Step 1: Prepare Your Project

### Required Files (Check These Exist)
✅ `start.sh` - How to run your app (should be in root)
✅ `backend/main.py` - FastAPI app
✅ `backend/requirements.txt` - Dependencies
✅ `backend/Procfile` - Optional but helpful

Your project structure should look like:
```
fyp_zy/
├── start.sh ← This file (created for you)
├── backend/
│   ├── main.py
│   ├── requirements.txt
│   └── Procfile
├── lib/
├── android/
└── ...
```

---

## Step 2: Push to GitHub

Make sure your code is on GitHub:

```bash
cd c:\Users\Zy231\StudioProjects\fyp_zy

# If not already a git repo
git init
git add .
git commit -m "Add start.sh for Render"

# If first time pushing
git remote add origin https://github.com/YOUR_USERNAME/fyp_zy.git
git branch -M main
git push -u origin main

# If already have remote, just push
git push
```

✅ Check on github.com that your code is there

---

## Step 3: Deploy on Render

### Create Render Account
1. Go to **[render.com](https://render.com)**
2. Click **"Sign Up"**
3. Choose **"Sign up with GitHub"** (easiest)
4. Authorize Render

### Deploy from GitHub

1. After login, click **"New +"** (top right)
2. Select **"Web Service"**
3. Choose **"Deploy an existing repository"**
4. Select your **`fyp_zy`** repo
5. Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `fyp-zy-backend` |
| **Environment** | `Python 3` |
| **Build Command** | `pip install -r backend/requirements.txt` |
| **Start Command** | `bash start.sh` |
| **Plan** | `Free` |

6. Click **"Create Web Service"**
7. Wait **3-5 minutes** for build & deployment

✅ When green checkmark appears: Deployment successful!

---

## Step 4: Get Your Backend URL

### Find Domain
1. Go to your Render dashboard
2. Click on your service: `fyp-zy-backend`
3. At top, you'll see: `https://fyp-zy-backend.onrender.com`
4. Copy this URL!

### Test Backend
Visit in browser:
```
https://fyp-zy-backend.onrender.com/docs
```

Should see FastAPI Swagger UI ✅

---

## Step 5: Update Flutter App

Edit: `lib/services/budget_forecast_service.dart`

```dart
// Line ~51, change from:
static const String _backendUrl = 'http://127.0.0.1:8000';

// To your Render URL:
static const String _backendUrl = 'https://fyp-zy-backend.onrender.com';
```

### Rebuild Flutter
```bash
flutter clean
flutter pub get
flutter run
```

✅ App now connects to Render backend!

---

## Step 6: Test Everything

### Test Backend
1. Visit `https://fyp-zy-backend.onrender.com/docs`
2. Click `/forecast` → **Try it out** → Send test data
3. Should return predictions ✅

### Test from Flutter App
1. Open Budget Forecasting page
2. Select a budget with 3+ months data
3. Should see forecasts & alerts from cloud ✅

---

## Understanding Auto-Sleep

⚠️ **Render sleeps after 15 minutes of inactivity**

- First request to sleeping app: **30-40 seconds** to wake up
- Subsequent requests: Normal speed
- No cost impact, just slower first use

**To keep it always awake:**
- Upgrade to **Paid Plan** ($7/month minimum)
- Or accept the slow first request

---

## Common Issues & Fixes

| Problem | Solution |
|---------|----------|
| **Build fails** | Check "Logs" tab - most likely missing dependencies in `requirements.txt` |
| **Port error** | `start.sh` must use `$PORT` environment variable |
| **Can't connect from Flutter** | Check CORS enabled in `main.py` (it should be) |
| **Timeout errors** | Prophet model takes 1-2 min; increase timeout in Flutter code |
| **Always shows "Building"** | Click "Cancel" and redeploy from dashboard |

### View Logs
1. Go to your service
2. Click **"Logs"** tab
3. Watch in real-time as build progresses
4. Errors show immediately

---

## Advanced: Custom Domain

Want `https://mybudgetapp.com` instead of `onrender.com`?

1. Buy domain (Namecheap, GoDaddy, etc.)
2. In Render: **Settings** → **Custom Domain**
3. Add your domain
4. Update DNS records as Render instructs
5. Update Flutter URL to use custom domain

*Optional - `onrender.com` domain works fine!*

---

## Monitoring & Updates

### Check Status
- Render dashboard shows live status (green = running)
- Click "Logs" to see activity

### Update Backend
```bash
# Make code changes locally
# Commit and push to GitHub
git add .
git commit -m "Updated forecast logic"
git push origin main

# Render auto-redeploys! (within 2-3 minutes)
# Watch the dashboard for deployment progress
```

### Monitor Usage
- **Free tier**: 750 dyno-hours/month (30 days × 24 = 720 hours)
- Your app uses ~$0/month on free tier
- All-day usage = staying within free limit ✅

---

## Backup Plan: Revert to Local

If Render fails:
1. Change Flutter URL back to `http://127.0.0.1:8000`
2. Run backend locally: `python main.py`
3. Works immediately ✅

---

## Need Help?

**Render Docs**: [render.com/docs](https://render.com/docs)
**FastAPI Deployment**: [fastapi.tiangolo.com/deployment](https://fastapi.tiangolo.com/deployment/)

