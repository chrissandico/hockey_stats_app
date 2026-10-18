# Enable GitHub Pages - Step by Step

## Current Status
- ❌ GitHub Pages not yet enabled
- ✅ Privacy policy files are in the repository (docs/index.html)
- ✅ Repository: https://github.com/chrissandico/hockey_stats_app

## Step-by-Step Instructions

### Step 1: Go to Repository Settings

1. Open your browser and go to:
   ```
   https://github.com/chrissandico/hockey_stats_app
   ```

2. Click the **Settings** tab (top right, next to Insights)

### Step 2: Navigate to Pages

1. In the left sidebar, scroll down and click **Pages**
   - It's under "Code and automation" section
   - Look for the icon that looks like a page/document

### Step 3: Configure Source

You should see a section called "Build and deployment"

1. Under **Source**, click the dropdown (currently says "None")
2. Select **Deploy from a branch**

3. Under **Branch**:
   - First dropdown: Select **master** (or main if that's your default)
   - Second dropdown: Select **/docs**
   - Click **Save**

### Step 4: Wait for Deployment

After clicking Save:
1. GitHub will show a message: "GitHub Pages source saved"
2. Wait 1-3 minutes for the site to build
3. Refresh the page

You should see a message like:
```
Your site is live at https://chrissandico.github.io/hockey_stats_app/
```

### Step 5: Verify Privacy Policy

Once deployed, visit:
```
https://chrissandico.github.io/hockey_stats_app/
```

You should see your privacy policy page with:
- "The Shift" branding
- Professional styling
- All privacy policy sections

## Troubleshooting

### Issue: "Pages" option not visible in Settings

**Solution**: Make sure you're logged into GitHub and have admin access to the repository.

### Issue: Still getting 404 after enabling

**Possible causes:**

1. **Not enough time passed**
   - Wait 2-3 minutes after enabling
   - Try clearing browser cache (Ctrl+Shift+R or Cmd+Shift+R)

2. **Wrong branch selected**
   - Go back to Settings → Pages
   - Verify branch is set to "master" (not "main")
   - Verify folder is set to "/docs"

3. **Files not in repository**
   - Verify files exist: https://github.com/chrissandico/hockey_stats_app/tree/master/docs
   - Should see: index.html and README.md

4. **Repository is private**
   - GitHub Pages requires public repository (for free accounts)
   - Go to Settings → General → scroll to bottom
   - Check if repository is public
   - If private, click "Change visibility" → "Make public"

### Issue: Repository is Private

If your repository is private, you have two options:

**Option A: Make Repository Public** (Recommended for app with public Play Store listing)
1. Go to Settings → General
2. Scroll to "Danger Zone" at bottom
3. Click "Change visibility"
4. Select "Make public"
5. Type repository name to confirm
6. Click "I understand, change repository visibility"

**Option B: Keep Private and Use Alternative**
If you want to keep the repo private, you can:
1. Use GitHub Gist for privacy policy (see alternative below)
2. Host privacy policy on your own website
3. Upgrade to GitHub Pro ($4/month) for private repo Pages

## Alternative: Use GitHub Gist (If Repo Must Stay Private)

If you need to keep the repository private:

1. Go to https://gist.github.com
2. Click "New gist"
3. Filename: `privacy-policy.html`
4. Copy contents from `docs/index.html` and paste
5. Click "Create public gist"
6. Click "Raw" button
7. Copy that URL for Play Store

**Note**: Gist URL will look like:
```
https://gist.githubusercontent.com/chrissandico/[hash]/raw/[hash]/privacy-policy.html
```

## Verification Checklist

Once GitHub Pages is enabled:

- [ ] Visit https://chrissandico.github.io/hockey_stats_app/
- [ ] Privacy policy loads correctly
- [ ] Page is mobile-responsive (test on phone)
- [ ] Email shows as chris@professormeta.io
- [ ] All sections are present
- [ ] No broken links or formatting issues

## What to Do After It's Working

1. **Copy the URL**:
   ```
   https://chrissandico.github.io/hockey_stats_app/
   ```

2. **Use in Play Store**:
   - Google Play Console → Store Listing → Privacy Policy
   - Paste the URL
   - Save

3. **Test the URL**:
   - Open in browser
   - Open on mobile device
   - Share with a friend to verify it's publicly accessible

## Expected Timeline

- **Enabling Pages**: 30 seconds
- **First deployment**: 1-3 minutes
- **Subsequent updates**: 1-2 minutes

## Need Help?

If you're still having issues after following these steps:

1. **Check repository visibility**:
   - Go to https://github.com/chrissandico/hockey_stats_app
   - Look for "Public" or "Private" badge under repository name

2. **Check GitHub Pages status**:
   - Settings → Pages
   - Look for green checkmark and "Your site is published at..."

3. **Check GitHub Actions** (if available):
   - Go to "Actions" tab in repository
   - Look for "pages build and deployment" workflow
   - Check if it succeeded or failed

## Quick Test

Run this command to verify docs are in the repo:
```bash
git ls-files docs/
```

Should show:
```
docs/README.md
docs/index.html
```

If these files are missing, the docs folder wasn't pushed. Run:
```bash
git add docs/
git commit -m "Add privacy policy for GitHub Pages"
git push origin master
```

---

**Repository**: https://github.com/chrissandico/hockey_stats_app  
**Expected URL**: https://chrissandico.github.io/hockey_stats_app/  
**Status**: Waiting for you to enable GitHub Pages in Settings
