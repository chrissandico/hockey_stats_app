# Adding Custom Team Logos to Hockey Stats App

This document explains how to add custom team logos to the Hockey Stats App.

## Current Implementation

The app currently uses programmatically generated logos based on team names:
- Your team (Waxers) is represented by a blue circle with "W"
- Opponent teams are represented by a red circle with the first letter of the opponent's name

## Adding Custom Logo Images

To replace these with custom images, follow these steps:

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
   ```
3. Run `flutter pub get` to update the asset references

### 3. Modify the TeamUtils Class

Edit the `lib/utils/team_utils.dart` file to use your custom logo files instead of the generated ones:

```dart
static Widget getTeamLogo(String teamName, {double size = 40.0}) {
  // Convert team name to lowercase for case-insensitive comparison
  final name = teamName.toLowerCase();
  
  // Check for specific team names and return appropriate logo
  if (name.contains('waxers') || name == 'your team') {
    // Use custom Waxers logo
    return Image.asset(
      'assets/logos/waxers_logo.png',
      width: size,
      height: size,
    );
  } else if (name.contains('chiefs')) {
    // Use custom Chiefs logo
    return Image.asset(
      'assets/logos/chiefs_logo.png',
      width: size,
      height: size,
    );
  } else {
    // For other teams, you can either:
    // 1. Add more specific cases for other teams
    // 2. Use a generic opponent logo
    // 3. Keep the current dynamic logo generation
    
    // Example of a generic opponent logo:
    return Image.asset(
      'assets/logos/generic_opponent.png',
      width: size,
      height: size,
    );
    
    // Or keep the current dynamic generation:
    /*
    final firstLetter = teamName.isNotEmpty ? teamName[0].toUpperCase() : 'O';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.5,
          ),
        ),
      ),
    );
    */
  }
}
```

### 4. Advanced: Creating a Team Logo Database

For a more scalable solution with many teams:

1. Create a JSON file in `assets/data/team_logos.json`:
   ```json
   {
     "waxers": "assets/logos/waxers_logo.png",
     "chiefs": "assets/logos/chiefs_logo.png",
     "rivals": "assets/logos/rivals_logo.png",
     "default": "assets/logos/generic_logo.png"
   }
   ```

2. Update the TeamUtils class to load this JSON file and use it to map team names to logo files.

## Tips for Logo Design

- Use transparent backgrounds (PNG format)
- Keep logos simple and recognizable at small sizes
- Maintain consistent dimensions for all logos
- Consider creating both light and dark versions for different themes

## Example Logo Sources

- Team websites
- Sports clip art libraries
- Custom designs from graphic designers
- Vector graphics that you can resize and export as PNG
