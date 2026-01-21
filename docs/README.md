# Privacy Policy - GitHub Pages Setup

This folder contains the privacy policy for The Shift app, hosted on GitHub Pages.

## Files

- `index.html` - Privacy policy page (mobile-responsive, professional design)

## Setup Instructions

### 1. Enable GitHub Pages

1. Go to your GitHub repository
2. Click on "Settings" tab
3. Scroll down to "Pages" section (left sidebar)
4. Under "Source", select:
   - **Branch**: `main` (or your default branch)
   - **Folder**: `/docs`
5. Click "Save"
6. Wait 1-2 minutes for deployment

### 2. Access Your Privacy Policy

Once deployed, your privacy policy will be available at:

```
https://[your-username].github.io/[repository-name]/
```

For example:
- If username is `professormeta` and repo is `hockey-stats-app`:
- URL: `https://professormeta.github.io/hockey-stats-app/`

### 3. Use in Play Store

Copy the URL and paste it into:
- Google Play Console → Store Listing → Privacy Policy URL
- Google Play Console → App Content → Privacy Policy

### 4. Custom Domain (Optional)

If you want a custom domain like `privacy.theshift.app`:

1. Purchase a domain
2. Add a `CNAME` file to the `docs` folder with your domain
3. Configure DNS settings with your domain provider
4. Update GitHub Pages settings to use custom domain

## Updating the Privacy Policy

To update the privacy policy:

1. Edit `docs/index.html`
2. Update the "Last Updated" date
3. Commit and push changes
4. GitHub Pages will automatically redeploy (takes 1-2 minutes)

## Testing Locally

To test the privacy policy locally:

1. Open `docs/index.html` in your web browser
2. Or use a local server:
   ```bash
   cd docs
   python -m http.server 8000
   ```
3. Visit `http://localhost:8000` in your browser

## Features

- ✅ Mobile-responsive design
- ✅ Professional styling
- ✅ Easy to read and navigate
- ✅ Includes all required sections for Play Store
- ✅ GDPR and CCPA compliant
- ✅ Contact information included
- ✅ Clear data collection and usage explanations

## Customization

Before deploying, update these placeholders in `index.html`:

- [ ] Email addresses (currently: support@professormeta.io, privacy@professormeta.io)
- [ ] Company/developer name (currently: Professor Meta)
- [ ] Website URL (if you have one)
- [ ] Any specific details about your implementation

## Required Sections (All Included ✓)

- [x] What data is collected
- [x] How data is used
- [x] How data is stored and protected
- [x] Data sharing and disclosure
- [x] User rights (access, delete, export)
- [x] Children's privacy (COPPA)
- [x] International data transfers
- [x] California privacy rights (CCPA)
- [x] European privacy rights (GDPR)
- [x] Contact information
- [x] Changes to policy
- [x] Data retention

## Notes

- The privacy policy is specifically tailored for The Shift app
- All sections are Google Play Store compliant
- Includes specific details about offline functionality and Google Sheets integration
- Clearly states what data is NOT collected
- Emphasizes user control over their data
- Professional appearance suitable for app store submission

## Support

If you need help with GitHub Pages setup:
- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [GitHub Pages Quickstart](https://docs.github.com/en/pages/quickstart)
