# Deploy Backend to Railway - Complete Guide

## Why Railway?
- ✅ **Free tier**: $5 credit/month (covers most deployments)
- ✅ **Simple**: Auto-detects Python, handles dependencies
- ✅ **Fast**: Deploys in 2-3 minutes
- ✅ **24/7**: No auto-sleep like other platforms
- ✅ **No credit card**: Required initially, but generous free tier

---

## Step 1: Prepare Your Project

### Required Files (Check These Exist)
✅ `backend/main.py` - Flask/FastAPI app
✅ `backend/requirements.txt` - Dependencies
✅ `README.md` - (helpful but optional)

### Create Procfile (Railway needs this)
In `backend/` folder, create file: `Procfile`
```
web: uvicorn main:app --host 0.0.0.0 --port $PORT
```

### Update requirements.txt (if needed)
Make sure it includes:
```
fastapi==0.104.1
uvicorn==0.24.0
pandas==2.1.1
numpy==1.24.3
pystan==3.7.0
cmdstanpy==1.1.0
prophet==1.1.5
pydantic==2.5.0
python-multipart==0.0.6
gunicorn==21.2.0
```

---

## Step 2: Push to GitHub

Railway needs your code in a git repo.

```bash
# Navigate to project root
cd c:\Users\Zy231\StudioProjects\fyp_zy

# Initialize git (if not already done)
git init
git add .
git commit -m "Initial commit with backend"

# Create new repo on GitHub.com
# Then push:
git remote add origin https://github.com/YOUR_USERNAME/fyp_zy.git
git branch -M main
git push -u origin main
```

---

## Step 3: Deploy on Railway

### Create Railway Account
1. Go to **[railway.app](https://railway.app)**
2. Click "Start New Project"
3. Sign up with GitHub (easiest)

### Deploy from GitHub
1. After login, click **"New Project"**
2. Select **"Deploy from GitHub"**
3. Authorize Railway to access your GitHub
4. Select repository: **`fyp_zy`**
5. Railway automatically detects **Python** → builds & deploys!

### Wait for Build
ℹ️ First deployment takes **2-3 minutes**
- Building dependencies (Prophet is large)
- Deploying to Railway servers
- Watch the logs in dashboard

✅ When green: Deployment successful!

---

## Step 4: Get Your Backend URL

### Find Domain URL
1. In Railway dashboard, go to your project
2. Click on **"Deployments"** tab
3. Find your **domain URL**: `https://fyp_zy-production.up.railway.app`
4. Test it: Visit `https://YOUR_DOMAIN/docs`

Should see FastAPI Swagger UI ✅

---

## Step 5: Update Flutter App

Edit: `lib/services/budget_forecast_service.dart`

```dart
// Line ~51, change from:
static const String _backendUrl = 'http://127.0.0.1:8000';

// To your Railway URL:
static const String _backendUrl = 'https://fyp_zy-production.up.railway.app';
```

### Rebuild Flutter
```bash
flutter clean
flutter pub get
flutter run
```

✅ App now connects to cloud backend!

---

## Step 6: Test Everything Works

### Test Backend Directly
Visit in browser:
```
https://YOUR_DOMAIN/docs
```
Click `/forecast` → **Try it out** → Send test data
Should return predictions ✅

### Test from Flutter App
1. Open Budget Forecasting page
2. Select a budget with 3+ months data
3. Should see forecasts & alerts loaded from cloud ✅

---

## Common Issues & Fixes

| Problem | Solution |
|---------|----------|
| **Port binding error** | Procfile must use `$PORT` variable |
| **Missing dependencies** | Make sure all imports are in `requirements.txt` |
| **Timeout errors** | Prophet fits might take 1-2 min; increase timeout in Flutter |
| **Can't connect from Flutter** | Check CORS is enabled in main.py (it should be) |
| **Build fails** | Check logs in Railway dashboard → Deployments |

### View Logs
In Railway dashboard:
1. Go to your project
2. Click **"Logs"** tab
3. See real-time output
4. Errors show here immediately

---

## Advanced: Custom Domain

If you want `https://mybudgetapp.com` instead of `up.railway.app`:

1. Buy domain (Namecheap, GoDaddy, etc.)
2. In Railway: Settings → Domains
3. Add custom domain + point DNS to Railway
4. Update Flutter URL to use custom domain

*Optional - Railway default domain works fine!*

---

## Monitoring & Updates

### Check Status
- Railway dashboard always shows live status
- Green = running, Red = errors
- Click "Logs" to debug issues

### Update Backend
```bash
# Make code changes
# Commit & push to GitHub
git add .
git commit -m "Updated forecast logic"
git push origin main

# Railway auto-redeploys! (within 1-2 minutes)
```

### View Usage
- **Dyno hours**: Keep track of monthly usage
- **Free tier**: 750 dyno-hours/month
- Your app uses ~$1-2/month on free tier

---

## Backup Plan: Revert to Local

If cloud deployment fails:
1. Change Flutter URL back to `http://127.0.0.1:8000`
2. Run backend locally: `python main.py`
3. Works immediately ✅

---

## Need Help?

**Railway Docs**: [docs.railway.app](https://docs.railway.app)
**FastAPI Deployment**: [fastapi.tiangolo.com/deployment](https://fastapi.tiangolo.com/deployment/)

