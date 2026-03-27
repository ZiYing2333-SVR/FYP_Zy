# Smart Budgeting Prophet Backend - Windows Setup & Troubleshooting

## 🪟 Windows-Specific Setup

### Step 1: Open Command Prompt in Backend Folder

1. Open `c:\Users\Zy231\StudioProjects\fyp_zy\backend`
2. Hold `Shift + Right Click` → "Open PowerShell window here"
3. Or use Command Prompt and navigate:
```cmd
cd c:\Users\Zy231\StudioProjects\fyp_zy\backend
```

### Step 2: Create Virtual Environment

```cmd
python -m venv venv
```

If you get "python: command not found":
- Add Python to PATH or use `python3` or `py`
- Install Python from python.org if not installed

### Step 3: Activate Virtual Environment

```cmd
venv\Scripts\activate
```

You should see `(venv)` prefix in terminal.

### Step 4: Install Dependencies

```cmd
pip install -r requirements.txt
```

**Expected output:**
```
Successfully installed fastapi-0.104.1 uvicorn-0.24.0 pandas-2.1.1 ...
```

⏱️ **Wait 5-10 minutes** for Prophet to compile.

### Step 5: Start Backend Server

```cmd
python main.py
```

**Expected output:**
```
INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
```

Keep this terminal open!

### Step 6: Test Backend (in new terminal)

```cmd
curl http://127.0.0.1:8000/health
```

Or open browser:
```
http://127.0.0.1:8000/docs
```

---

## 📱 Android Emulator Configuration

If you're using Android Emulator, change the backend URL:

**File**: `lib/services/budget_forecast_service.dart`

```dart
// Change this:
static const String _backendUrl = 'http://127.0.0.1:8000';

// To this (for Android Emulator):
static const String _backendUrl = 'http://10.0.2.2:8000';

// Or for physical device on network:
static const String _backendUrl = 'http://YOUR_COMPUTER_IP:8000';
```

### Finding Your Computer IP:

**Windows**, open Command Prompt:
```cmd
ipconfig
```

Look for "IPv4 Address" (e.g., 192.168.x.x)

Then use:
```dart
static const String _backendUrl = 'http://192.168.x.x:8000';
```

---

## 🐛 Common Windows Issues & Solutions

### Issue 1: "Python is not recognized"

**Solution**: Install Python or use `py` instead

```cmd
py -m venv venv
py -m pip install -r requirements.txt
py main.py
```

Or add Python to PATH:
1. Search "Environment Variables"
2. Click "Edit the system environment variables"
3. Click "Environment Variables..."
4. Add Python folder to PATH (e.g., `C:\Users\YourName\AppData\Local\Programs\Python\Python311`)
5. Restart terminal

### Issue 2: "Address already in use :8000"

**Solution**: Kill existing process

```cmd
# Find process using port 8000
netstat -ano | findstr :8000

# Kill process (replace PID with number from above)
taskkill /PID [PID] /F

# Or use different port in main.py:
# uvicorn.run(app, host="0.0.0.0", port=8001)
```

### Issue 3: "pip: command not found"

**Solution**: Use Python module:

```cmd
python -m pip install -r requirements.txt
```

### Issue 4: Prophet installation fails

**Solution A**: Use binary wheel (faster)
```cmd
pip install --upgrade setuptools wheel
pip install prophet
```

**Solution B**: Build from source (slower, more compatible)
```cmd
pip install --no-binary :all: prophet
```

**Solution C**: Use Conda (if you have Anaconda)
```cmd
conda install -c conda-forge prophet
conda install -c conda-forge pystan
```

### Issue 5: Can't connect from Flutter

**For Physical Device**:
1. Make sure phone and PC on same WiFi
2. Get PC IP: `ipconfig` → IPv4 Address (e.g., 192.168.1.100)
3. Update Flutter code with that IP:
```dart
static const String _backendUrl = 'http://192.168.1.100:8000';
```
4. Make sure firewall allows port 8000 (Windows Defender Firewall)

**For Android Emulator**:
```dart
static const String _backendUrl = 'http://10.0.2.2:8000';
```

### Issue 6: No data showing in Flutter app

**Check backend logs**:
1. Backend terminal should show API calls
2. Look for errors starting with `ERROR:` or `Traceback`
3. If empty, Flutter app isn't calling the API

**Check Flutter logs**:
1. Run Flutter in terminal: `flutter run -v`
2. Look for network errors or connection refused

**Check data**:
1. Navigate to Budget Forecasting screen
2. Select a budget that has 3+ months of transactions
3. Wait for data to load

---

## 🧪 Testing the Backend Manually

### Test 1: Health Check

```cmd
curl http://127.0.0.1:8000/health
```

Expected response:
```json
{"status":"healthy","version":"1.0.0"}
```

### Test 2: API Documentation

Open browser:
```
http://127.0.0.1:8000/docs
```

Click on `/forecast` → "Try it out" → Enter test data

### Test 3: Make POST Request

**Using PowerShell**:
```powershell
$body = @{
    historical_data = @(
        @{date = "2024-01-01"; amount = 1000},
        @{date = "2024-02-01"; amount = 1200},
        @{date = "2024-03-01"; amount = 1100}
    )
    forecast_periods = 3
    budget_amount = 2000
} | ConvertTo-Json

Invoke-WebRequest -Uri http://127.0.0.1:8000/forecast `
    -Method Post `
    -Headers @{"Content-Type"="application/json"} `
    -Body $body
```

Expected response: JSON with forecast data

---

## 📊 Monitoring Backend Health

### Real-time Logs

Terminal displays detailed logs:
```
INFO:     Uvicorn running on http://127.0.0.1:8000
DEBUG:    GET /health
DEBUG:    POST /forecast (processing)
DEBUG:    Prophet model trained on 12 months of data
DEBUG:    Forecast generated: 3 periods
INFO:     GET /health 200 OK
```

### Check CPU & Memory

**Windows Task Manager**:
1. Press `Ctrl + Shift + Esc`
2. Find `python.exe` running main.py
3. Observe CPU and Memory usage
4. Prophet uses ~200MB RAM while training

---

## 🔧 Advanced Configuration

### Change Port (if 8000 taken)

**File**: `backend/main.py`

```python
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)  # Changed to 8001
```

Then in Flutter:
```dart
static const String _backendUrl = 'http://127.0.0.1:8001';
```

### Enable HTTPS (Production Only)

```python
uvicorn.run(app, 
    host="0.0.0.0", 
    port=8000,
    ssl_keyfile="path/to/key.pem",
    ssl_certfile="path/to/cert.pem"
)
```

### Add Rate Limiting

```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter

@app.post("/forecast")
@limiter.limit("10/minute")  # Max 10 requests per minute
async def generate_forecast(request: ForecastRequest):
    ...
```

---

## 📈 Performance Tips

### Reduce Training Time
In `backend/main.py`, reduce data used:

```python
# Use last 6 months instead of 12 (faster, less seasonal)
forecast = model.predict(future)
```

### Faster Response

Backend response time depends on:
- Historical data points (more = slower)
- Forecast periods (more = slower)
- Server load

Expected: 1-3 seconds per forecast

### Monitor Performance

Add timing to see where time is spent:

```python
import time

@app.post("/forecast")
async def generate_forecast(request: ForecastRequest):
    start = time.time()
    
    # ... processing ...
    
    duration = time.time() - start
    print(f"Forecast completed in {duration:.2f} seconds")
    
    return response
```

---

## 🚀 Production Checklist

Before deploying to production:

- [ ] Test locally and confirm it works
- [ ] Test from physical device on WiFi
- [ ] Have 3+ months of sample transaction data
- [ ] Choose deployment platform (Render/Railway/Replit)
- [ ] Update `_backendUrl` with production URL
- [ ] Test production URL works
- [ ] Monitor first few days for errors
- [ ] Collect feedback from users

---

## 🆘 Debugging Steps (In Order)

1. **Check backend is running**
   - See "INFO: Uvicorn running" in terminal?

2. **Check health endpoint**
   - `curl http://127.0.0.1:8000/health`
   - Should return JSON with status=healthy

3. **Check API docs**
   - Open `http://127.0.0.1:8000/docs` in browser
   - Can you see swagger UI?

4. **Check network connection**
   - From Flutter, can you ping backend?
   - For physical device: same WiFi network?
   - For emulator: correct IP (10.0.2.2)?

5. **Check data**
   - Does budget have 3+ months of transactions?
   - Check Supabase to confirm data exists

6. **Check logs**
   - Backend: Any error messages in terminal?
   - Flutter: Run with `flutter run -v` for verbose logs
   - Phone: Check device logs with `adb logcat`

7. **Reset & retry**
   - Stop backend (Ctrl+C)
   - Deactivate venv: `deactivate`
   - Delete `venv` folder
   - Start fresh from Step 2

---

## 📞 Support Commands

```cmd
# See Python version
python --version

# Check pip packages installed
pip list

# Check what's using port 8000
netstat -ano | findstr :8000

# Reinstall all dependencies
pip install --upgrade -r requirements.txt

# Clear cache and reinstall
pip install --no-cache-dir -r requirements.txt

# Test specific import
python -c "import prophet; print(prophet.__version__)"
```

---

## ✅ Success Checklist

✓ Backend runs without errors
✓ Health check returns 200 OK
✓ API docs load at /docs
✓ Forecast returns predictions
✓ Flutter app connects successfully
✓ Budget Forecasting screen shows predictions
✓ Alert status displays correctly
✓ MAE accuracy metric shows

Once all ✓, your Prophet forecasting system is ready! 🎉
