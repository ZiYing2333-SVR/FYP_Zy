# Smart Budgeting with Prophet - Quick Start (5 Minutes)

## 🚀 Just Want It Working? Start Here!

### 1. Open Terminal/Command Prompt

Go to: `c:\Users\Zy231\StudioProjects\fyp_zy\backend`

### 2. Create & Activate Virtual Environment
```bash
python -m venv venv
venv\Scripts\activate
```

### 3. Install Dependencies
```bash
pip install -r requirements.txt
```
⏱️ **Wait 5-10 minutes** for Prophet to install

### 4. Start Backend Server
```bash
python main.py
```

You should see:
```
INFO:     Uvicorn running on http://127.0.0.1:8000
```

✅ **Done!** Leave this terminal running.

### 5. Open Flutter App

The app automatically connects to the backend!

Navigate to: **Budget Forecasting** → Select a budget → See predictions

---

## 📊 What You Get

- ✅ **Spending Forecast**: Next 3 months predicted
- ✅ **Smart Alerts**: Green (safe) / Orange (warning) / Red (critical)
- ✅ **Confidence Level**: Upper & lower bounds
- ✅ **Accuracy Score**: MAE (Mean Absolute Error)

---

## 🔧 For Different Device Types

### Desktop / Flutter Web
Works automatically! ✅

### Android Emulator
Edit: `lib/services/budget_forecast_service.dart`
```dart
// Change:
static const String _backendUrl = 'http://127.0.0.1:8000';
// To:
static const String _backendUrl = 'http://10.0.2.2:8000';
```

### Physical Android Phone
1. Get your computer IP:
```bash
ipconfig
# Look for IPv4 Address (e.g., 192.168.1.100)
```

2. Edit Flutter code:
```dart
static const String _backendUrl = 'http://192.168.1.100:8000';
```

3. Make sure same WiFi ✅

---

## ⚠️ Common Issues

| Problem | Solution |
|---------|----------|
| "python not found" | Use `py` instead: `py main.py` |
| "Address already in use" | Kill on port 8000 or use different port |
| "No data showing" | Budget needs 3+ months of transactions |
| "Can't connect" | Check backends running + correct backend URL |

---

## 📡 Test Backend is Working

Open in browser:
```
http://127.0.0.1:8000/docs
```

Click `/forecast` → **Try it out** → Send test data

If it returns predictions, backend is working! ✅

---

## ☁️ Deploy to Cloud (Keep Running 24/7)

### Option: Render (Recommended - Simple)

**1. Create Render Account**
- Go to [render.com](https://render.com)
- Sign up with GitHub (easiest!)

**2. Deploy from GitHub**
- Click "New Web Service"
- Select your `fyp_zy` GitHub repo
- Railway auto-detects Python + builds!
- Takes 3-5 minutes

**3. Get Your Backend URL**
- Render shows: `https://fyp-zy-backend.onrender.com`
- Copy this URL!

**4. Update Flutter App**
Edit `lib/services/budget_forecast_service.dart`:
```dart
// Change from:
static const String _backendUrl = 'http://127.0.0.1:8000';

// To:
static const String _backendUrl = 'https://fyp-zy-backend.onrender.com';
```

**5. Rebuild & Deploy**
```bash
flutter pub get
flutter run
```

✅ **Done!** Your backend runs on Render

**Note**: Render auto-sleeps after 15 min (first request slower, then normal)

---

### Other Cloud Options

**Railway** (Fast, no auto-sleep)
- Same setup as Render but stays always-on
- See RAILWAY_DEPLOYMENT_GUIDE.md

**Replit** (Always-on free tier)
- Simplest to start but limited resources

---

### Local Development Still Needed?

Keep using `http://127.0.0.1:8000` locally. Only switch to cloud URL for:
- ✅ Testing on real Android phone
- ✅ Production/sharing with others

---

## 📚 Need More Help?

- **Full Setup**: `SMART_BUDGETING_PROPHET_SETUP.md`
- **Windows Issues**: `WINDOWS_SETUP_GUIDE.md`
- **Backend Details**: `backend/README.md`

---

## 🎯 Success Checklist

- [ ] Backend terminal shows "Uvicorn running"
- [ ] Browser shows `/docs` page
- [ ] Flutter app opens without errors
- [ ] Budget Forecasting screen loads
- [ ] See predictions & alerts

All checked? ✨ **You're done!** Enjoy smart budgeting! 🎉
