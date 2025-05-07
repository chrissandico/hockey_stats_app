# Adding Custom Team Logos to Hockey Stats App

This document explains how to add custom team logos to the Hockey Stats App.

## Current Implementation

The app now uses a JSON-based team logo database:
- Team logos are defined in `assets/data/team_logos.json`
- Each team has an ID, name, logo path, and team colors
- The app will automatically use the appropriate logo based on team name
- For teams without a specific logo, a fallback is generated based on the team name

## Team Logo Database

The app now uses a JSON-based team logo database located at `assets/data/team_logos.json`. This file contains:

```json
{
  "teams": [
    {
      "id": "waxers",
      "name": "Waxers",
      "logoPath": "assets/logos/waxers_logo.png",
      "primaryColor": "#1E88E5",
      "secondaryColor": "#FFFFFF"
    },
    {
      "id": "chiefs",
      "name": "Chiefs",
      "logoPath": "assets/logos/chiefs_logo.png",
      "primaryColor": "#D32F2F",
      "secondaryColor": "#FFFFFF"
    },
    ...
  ],
  "default": {
    "logoPath": "assets/logos/generic_logo.png",
    "primaryColor": "#757575",
    "secondaryColor": "#FFFFFF"
  }
}
```

## Adding Custom Team Logos

To add or update team logos:

### 1. Prepare Your Logo Files

- Create or obtain logo image files (PNG format recommended)
- Resize them to approximately 200x200 pixels
- Name them appropriately (e.g., `waxers_logo.png`, `chiefs_logo.png`)

### 2. Add Logo Files to the Project

1. Place your logo files in the `assets/logos/` directory
2. Make sure the `pubspec.yaml` file includes this directory:
   ```yaml
   flutter:
     assets:
       - assets/logos/
       - assets/data/
   ```
3. Run `flutter pub get` to update the asset references

### 3. Update the Team Logo Database

Edit the `assets/data/team_logos.json` file to add your new team:

```json
{
  "teams": [
    {
      "id": "waxers",
      "name": "Waxers",
      "logoPath": "assets/logos/waxers_logo.png",
      "primaryColor": "#1E88E5",
      "secondaryColor": "#FFFFFF"
    },
    {
      "id": "new_team",
      "name": "New Team",
      "logoPath": "assets/logos/new_team_logo.png",
      "primaryColor": "#9C27B0",
      "secondaryColor": "#FFFFFF"
    }
  ],
  "default": {
    "logoPath": "assets/logos/generic_logo.png",
    "primaryColor": "#757575",
    "secondaryColor": "#FFFFFF"
  }
}
```

## Using Team Colors

The app now supports team colors for UI elements. You can use these colors in your custom UI components:

```dart
// Get team colors
final primaryColor = TeamUtils.getPrimaryColor(teamName, context: context);
final secondaryColor = TeamUtils.getSecondaryColor(teamName, context: context);

// Use colors in UI elements
Container(
  decoration: BoxDecoration(
    color: primaryColor.withOpacity(0.1),
    border: Border.all(color: primaryColor),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    teamName,
    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
  ),
)
```

## Tips for Logo Design

- Use transparent backgrounds (PNG format)
- Keep logos simple and recognizable at small sizes (200x200 pixels recommended)
- Maintain consistent dimensions for all logos
- Choose contrasting primary and secondary colors for good visibility
- Test your logos at different sizes to ensure they remain recognizable

## Example Logo Sources

- Team websites
- Sports clip art libraries
- Custom designs from graphic designers
- Vector graphics that you can resize and export as PNG
- Online logo generators
