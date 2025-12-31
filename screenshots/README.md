# Screenshots

## Safety Feature Demonstration

Screenshots demonstrating the new safety feature where missions fail if players kill their own cattle.

### Required Screenshots

To properly document this feature, the following screenshots should be added:

1. **`normal_herding.png`** - Normal cattle herding in progress
   - Shows player herding cattle peacefully
   - HUD displaying herd count and status
   - All cattle alive and moving

2. **`player_shooting_cattle.png`** - Player shooting their own cattle
   - Shows the moment before mission failure
   - Player with weapon aimed at cattle
   - Demonstrates the exploit attempt

3. **`mission_failed_notification.png`** - Mission failure notification
   - Shows the error message: "⛔ MISSION FAILED: You killed your own cattle!"
   - Shows subtitle: "Your contract has been terminated."
   - Clear visibility of the notification system

4. **`herd_cleanup.png`** - After mission failure
   - Shows that all cattle entities have been cleaned up
   - Empty location where herd was
   - No remaining cattle visible

5. **`database_tracking.png`** - Database statistics
   - SQL query showing `failed_deliveries` column
   - Contract status marked as 'failed'
   - Player stats updated with cattle_lost

6. **`framework_detection.png`** - Console showing framework detection
   - Server/client console logs
   - Shows "Using framework: LXRCore" or "Using framework: RSG-Core"
   - Framework auto-detection in action

7. **`config_settings.png`** - Configuration file
   - Shows `Config.Framework` setting
   - Shows `Config.Security.fail_on_player_kill` option
   - Demonstrates configurability

## How to Capture Screenshots

### In-Game Screenshots
1. Start a cattle herding mission in RedM
2. Position camera for clear view
3. Use F12 (Steam) or PrtScn to capture
4. For mission failure: shoot a cattle and capture the notification

### Database Screenshots
1. Use phpMyAdmin or MySQL Workbench
2. Execute queries on `tlw_cattle_players` and `tlw_cattle_contracts` tables
3. Capture the results showing failed_deliveries tracking

### Console Screenshots
1. Start the resource with both frameworks installed
2. Capture the framework detection messages
3. Show debug output if Config.Debug = true

## Screenshot Placement

Once captured, place screenshots in this directory with the naming convention above. They will be automatically referenced in the README and SAFETY_FEATURE.md documentation.

## Format Requirements

- **Format:** PNG or JPEG
- **Resolution:** Minimum 1280x720, preferably 1920x1080
- **Quality:** High quality, clear visibility of UI elements
- **Annotations:** Consider adding arrows or highlights to key areas
- **File Size:** Optimize to keep under 2MB each

## Integration with Documentation

Update README.md with screenshot references:
```markdown
## 📸 Screenshots

### Safety Feature in Action
![Normal Herding](screenshots/normal_herding.png)
![Mission Failed](screenshots/mission_failed_notification.png)

### Database Tracking
![Database Stats](screenshots/database_tracking.png)
```

---

**Note:** These screenshots need to be captured in an actual RedM server environment. Since we're working in a development environment without access to the game, placeholder references have been created for documentation purposes.
