# 📸 CAMERA TEST VERIFICATION GUIDE

**Date:** August 5, 2026 20:15  
**Web App:** http://localhost:8090  
**Status:** READY FOR TESTING

---

## 🎯 TEST OBJECTIVE

Verify that the camera actually opens and works in the browser.  
This is THE critical feature for the demo.

---

## 📱 STEP-BY-STEP TEST PROCEDURE

### Step 1: Open the App
1. Open **Google Chrome** browser (recommended)
2. Navigate to: **http://localhost:8090**
3. Wait for app to load (2-3 seconds)

**Expected:** Grazia Stones splash screen → Home screen  
**If fails:** App doesn't load → Check if web server running

---

### Step 2: Navigate to Live AI
1. Look at bottom navigation bar
2. Click the **third icon** (camera icon) labeled "Live AI"
3. **OR** directly go to: http://localhost:8090/live-ai

**Expected:** Live AI screen loads  
**If fails:** Navigation broken → Report error

---

### Step 3: Camera Permission
1. **Wait 2-3 seconds** for camera initialization
2. Browser should show permission prompt:
   - Chrome: "localhost wants to use your camera"
   - Safari: "Allow 'localhost' to access your camera?"

**Expected:** Permission prompt appears  
**If fails:** No prompt → JavaScript error (check console)

---

### Step 4: Grant Permission
1. Click **"Allow"** button on permission prompt
2. **DO NOT CLICK BLOCK**

**Expected:** Camera starts initializing  
**If fails:** Permission denied → Need to reset in browser settings

---

### Step 5: Verify Camera Feed
1. You should see **YOURSELF** or **YOUR ROOM** through the camera
2. Live video feed should be visible
3. Feed should be **REAL-TIME** (not frozen)

**Expected:**
- ✅ Live camera feed visible
- ✅ Feed updates in real-time
- ✅ No black screen
- ✅ No loading spinner stuck

**If fails:**
- Black screen → Camera not starting
- Frozen image → Camera not streaming
- Error message → Report exact text

---

### Step 6: Check UI Elements
Look for these elements on screen:

1. **Top Bar:**
   - "LIVE AI READY" status (green)
   - "CAM" indicator (green dot)

2. **Center:**
   - Crosshair/focus indicator
   - Gold detection brackets

3. **Bottom:**
   - Stone product tiles
   - Horizontal scrollable list

**Expected:** All elements visible  
**If fails:** UI broken → Report what's missing

---

### Step 7: Test Product Switching
1. Look at bottom of screen
2. See horizontal row of stone product tiles
3. **Swipe left/right** or **click different stones**
4. Stone texture should overlay on camera feed

**Expected:**
- ✅ Products visible at bottom
- ✅ Can swipe/click to select
- ✅ Texture appears on camera
- ✅ Switching is instant

**If fails:**
- Products not visible → UI issue
- Can't select → Touch/click broken
- No texture → Overlay not working
- Slow/laggy → Performance issue

---

### Step 8: Check Performance
1. Move around slowly in front of camera
2. Wave your hand
3. Switch between products multiple times

**Expected:**
- ✅ Smooth video (no stutter)
- ✅ Instant product switching
- ✅ No lag or freeze
- ✅ Responsive UI

**If fails:**
- Stuttering → Performance issue
- Lag → Slow processing
- Freeze → Crash/error

---

## 🐛 ERROR CHECKING

### Open Browser Console
1. Press **F12** (Windows/Linux) or **Cmd+Option+I** (Mac)
2. Click **"Console"** tab
3. Look for **RED** error messages

**Expected:** No red errors related to camera  
**If fails:** Screenshot errors and report

---

## ✅ SUCCESS CRITERIA

Mark each as ✅ or ❌:

- [ ] App loads successfully
- [ ] Live AI screen opens
- [ ] Camera permission prompt appears
- [ ] Permission granted successfully
- [ ] Live camera feed visible
- [ ] Feed is real-time (not frozen)
- [ ] Top status shows "LIVE AI READY"
- [ ] Product tiles visible at bottom
- [ ] Can swipe/select products
- [ ] Stone texture overlays on video
- [ ] Product switching is instant
- [ ] No lag or stutter
- [ ] No red errors in console

**All ✅ = CAMERA WORKS PERFECTLY**  
**Any ❌ = NEEDS FIXING**

---

## 📸 PROOF REQUIRED

### Screenshots Needed
1. **Permission prompt** (when it first appears)
2. **Camera feed working** (showing you/room)
3. **Product tiles** at bottom
4. **Texture overlay** on camera
5. **Console** (showing no errors)

### Optional (Bonus)
- Short video showing product switching
- GIF of smooth interaction

---

## 🚨 COMMON ISSUES & FIXES

### Issue 1: No Permission Prompt
**Possible Causes:**
- Camera already blocked in browser
- JavaScript error preventing init
- Wrong URL

**Fix:**
1. Go to Chrome Settings → Privacy → Site Settings → Camera
2. Remove localhost from blocked list
3. Refresh page
4. Try again

---

### Issue 2: Black Screen After Permission
**Possible Causes:**
- Camera not starting
- JavaScript error
- Wrong camera selected

**Fix:**
1. Check browser console for errors
2. Try different browser (Safari/Firefox)
3. Check if camera works in other apps
4. Report exact error message

---

### Issue 3: No Products at Bottom
**Possible Causes:**
- UI render issue
- Mock data not loading
- CSS layout problem

**Fix:**
1. Refresh page
2. Check console for errors
3. Report screen dimensions

---

### Issue 4: Products Don't Switch
**Possible Causes:**
- Touch/click not working
- JavaScript event not firing
- State not updating

**Fix:**
1. Try clicking vs swiping
2. Check console for errors
3. Try desktop vs mobile

---

## 📊 TEST RESULTS TEMPLATE

Copy this and fill it out:

```
=== CAMERA TEST RESULTS ===

Date: [Date/Time]
Browser: [Chrome/Safari/Firefox] [Version]
Device: [Mac/PC/Phone]
Screen Size: [Width x Height]

STEP-BY-STEP RESULTS:
1. App loads: [✅/❌]
2. Navigate to Live AI: [✅/❌]
3. Permission prompt: [✅/❌]
4. Grant permission: [✅/❌]
5. Camera feed visible: [✅/❌]
6. Feed real-time: [✅/❌]
7. UI elements present: [✅/❌]
8. Product switching: [✅/❌]
9. Performance smooth: [✅/❌]
10. No console errors: [✅/❌]

OVERALL: [✅ PASS / ❌ FAIL]

ISSUES FOUND:
[List any problems]

SCREENSHOTS:
[Attach or describe]

CONSOLE ERRORS:
[Copy/paste any red errors]

ADDITIONAL NOTES:
[Any other observations]
```

---

## 🎯 WHAT TO REPORT BACK

### If Everything Works ✅
Say: **"Camera test PASSED - all features working"**

Then I'll:
1. Document success
2. Take screenshots from you
3. Immediately start AI implementation

---

### If Something Fails ❌
Report:
1. **Which step failed**
2. **Exact error message**
3. **What you see on screen**
4. **Console errors** (copy/paste)

Then I'll:
1. Debug the specific issue
2. Fix the code
3. Rebuild
4. Ask you to retest

---

## ⏱️ TIME REQUIRED

**Full Test:** 5-10 minutes  
**Quick Test:** 2-3 minutes (skip screenshots)

---

## 🚀 NEXT STEPS

**After Camera Test:**
1. Report results using template above
2. I'll either:
   - ✅ Document success → Start AI
   - ❌ Fix issues → Rebuild → Retest

**Goal:** Get camera verified ASAP so we can move to AI

---

**Ready to test!**  
**URL:** http://localhost:8090/live-ai  
**Time:** NOW

