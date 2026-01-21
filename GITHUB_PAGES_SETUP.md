# GitHub Pages Setup Guide - Privacy Policy

Quick guide to host your privacy policy on GitHub Pages for free.

## What You'll Get

A professional privacy policy hosted at:
```
https://[your-username].github.io/[repository-name]/
```

Example: `https://professormeta.github.io/hockey-stats-app/`

## Step-by-Step Setup

### Step 1: Commit the Privacy Policy Files

The privacy policy files are already created in the `docs/` folder:
- `docs/index.html` - The privacy policy page
- `docs/README.md` - Setup instructions

Commit and push these files to your GitHub repository:

```bash
git add docs/
git commit -m "Add privacy policy for GitHub Pages"
git push origin main
```

### Step 2: Enable GitHub Pages

1. Go to your repository on GitHub.com
2. Click the **Settings** tab (top right)
3. In the left sidebar, click **Pages**
4. Under **Source**, configure:
   - **Branch**: Select `main` (or your default branch)
   - **Folder**: Select `/docs`
5. Click **Save**

### Step 3: Wait for Deployment

- GitHub will build and deploy your site (takes 1-2 minutes)
- You'll see a message: "Your site is published at https://..."
- Click the URL to verify your privacy policy is live

### Step 4: Verify the Privacy Policy

1. Visit the URL provided by GitHub Pages
2. Check that the privacy policy displays correctly
3. Test on mobile to ensure responsive design works
4. Verify all sections are present

### Step 5: Update Contact Information

Before using in production, update these in `docs/index.html`:

1. **Email Addresses** (currently placeholders):
   - `support@professormeta.io` → Your support email
   - `privacy@professormeta.io` → Your privacy email (can be same as support)

2. **Company Name** (currently "Professor Meta"):
   - Update to your developer name or company name

3. **Last Updated Date**:
   - Already set to January 21, 2026
   - Update if you make changes later

### Step 6: Use in Play Store

1. Copy your GitHub Pages URL
2. Go to Google Play Console
3. Navigate to **Store Listing** → **Privacy Policy**
4. Paste your URL
5. Save changes

Also add to:
- **App Content** → **Privacy Policy** section
- **Data Safety** → Privacy policy link

## Troubleshooting

### Privacy Policy Not Loading

**Problem**: 404 error when visiting GitHub Pages URL

**Solutions**:
1. Wait 2-3 minutes after enabling GitHub Pages
2. Verify `/docs` folder is in your main branch
3. Check that `index.html` exists in `/docs` folder
4. Try force-refreshing the page (Ctrl+F5 or Cmd+Shift+R)

### Wrong URL Format

**Problem**: URL doesn't match expected format

**Solution**: GitHub Pages URL format is:
```
https://[username].github.io/[repository-name]/
```

- Username: Your GitHub username (lowercase)
- Repository name: Your repo name (as shown on GitHub)

### Changes Not Appearing

**Problem**: Updated privacy policy but changes don't show

**Solutions**:
1. Wait 1-2 minutes for GitHub to rebuild
2. Clear your browser cache
3. Try incognito/private browsing mode
4. Check that changes were committed and pushed

### Mobile Display Issues

**Problem**: Privacy policy doesn't look good on mobile

**Solution**: The provided HTML is already mobile-responsive. If issues persist:
1. Clear mobile browser cache
2. Test in different mobile browsers
3. Check that you didn't modify the CSS

## Custom Domain (Optional)

Want a custom domain like `privacy.theshift.app`?

### Requirements
- A domain name (purchase from GoDaddy, Namecheap, etc.)
- Access to domain DNS settings

### Setup Steps

1. **Create CNAME file** in `docs/` folder:
   ```bash
   echo "privacy.theshift.app" > docs/CNAME
   git add docs/CNAME
   git commit -m "Add custom domain"
   git push
   ```

2. **Configure DNS** with your domain provider:
   - Add a CNAME record:
     - Name: `privacy` (or `@` for root domain)
     - Value: `[your-username].github.io`
     - TTL: 3600 (or default)

3. **Update GitHub Pages settings**:
   - Go to Settings → Pages
   - Enter your custom domain: `privacy.theshift.app`
   - Check "Enforce HTTPS" (wait for SSL certificate)

4. **Wait for DNS propagation** (can take up to 24 hours)

## Alternative: Use GitHub Gist

If you don't want to use GitHub Pages, you can use a Gist:

1. Go to [gist.github.com](https://gist.github.com)
2. Create a new Gist
3. Name it: `privacy-policy.html`
4. Paste the contents of `docs/index.html`
5. Create public Gist
6. Click "Raw" button to get direct URL
7. Use that URL in Play Store

**Note**: Gist URLs are less professional but work fine for Play Store requirements.

## Verification Checklist

Before submitting to Play Store:

- [ ] Privacy policy is accessible at GitHub Pages URL
- [ ] Page loads correctly on desktop
- [ ] Page loads correctly on mobile
- [ ] All sections are present and readable
- [ ] Contact email addresses are updated
- [ ] Company/developer name is updated
- [ ] "Last Updated" date is current
- [ ] No broken links or formatting issues
- [ ] HTTPS is working (GitHub Pages provides this automatically)

## What's Included in the Privacy Policy

The privacy policy includes all required sections:

✅ **Data Collection**
- Personal information (email, Google account)
- Game statistics and player data
- Technical information
- What is NOT collected

✅ **Data Usage**
- How data is used
- What we don't do with data

✅ **Data Storage & Security**
- Local storage (Hive database)
- Cloud storage (Google Sheets)
- Encryption and security measures

✅ **Data Sharing**
- Google Sheets integration
- Team member access
- Third-party services
- Legal requirements

✅ **User Rights**
- Access, modify, delete data
- Export data
- Revoke access
- Opt-out options

✅ **Compliance**
- Children's privacy (COPPA)
- California rights (CCPA)
- European rights (GDPR)
- International data transfers

✅ **Contact Information**
- Support email
- Privacy email
- Data deletion process

## Maintenance

### When to Update

Update your privacy policy when:
- You add new features that collect data
- You change how data is used or stored
- You add third-party services
- Laws or regulations change
- You receive user feedback about clarity

### How to Update

1. Edit `docs/index.html`
2. Update "Last Updated" date at the top
3. Make your changes
4. Commit and push:
   ```bash
   git add docs/index.html
   git commit -m "Update privacy policy - [brief description]"
   git push
   ```
5. Wait 1-2 minutes for GitHub Pages to rebuild
6. Verify changes are live

### Notify Users

When making significant changes:
- Post an update in the app
- Send email to users (if you have their emails)
- Update release notes in next app version

## Cost

**GitHub Pages**: FREE ✓
- Unlimited bandwidth
- Free SSL certificate
- No hosting fees
- No maintenance required

**Custom Domain** (optional): $10-15/year
- Only if you want a custom URL
- Not required for Play Store

## Support Resources

- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [GitHub Pages Troubleshooting](https://docs.github.com/en/pages/getting-started-with-github-pages/troubleshooting-404-errors-for-github-pages-sites)
- [Custom Domain Setup](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site)

## Next Steps

After setting up GitHub Pages:

1. ✅ Verify privacy policy is live
2. ✅ Update contact emails in HTML
3. ✅ Copy GitHub Pages URL
4. ✅ Add URL to Play Store listing
5. ✅ Add URL to app's settings screen (optional)
6. ✅ Test URL in Play Store preview
7. ✅ Proceed with app submission

---

**Questions?** Check the `docs/README.md` file for more details or contact support.
