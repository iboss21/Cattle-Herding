# Safety Feature: Mission Failure on Cattle Kill

## Overview
This update adds a safety feature that prevents players from exploiting the cattle herding system by killing their own cattle for pelts and meat.

## Implementation Details

### What Changed
1. **Client-Side Detection**: Added real-time monitoring of cattle health
   - Checks every 100ms for cattle deaths
   - Detects if player or player's mount caused the death
   - Detects if player's weapon was used to kill cattle

2. **Mission Failure System**: 
   - Immediately terminates the mission when player kills their own cattle
   - Displays clear failure messages to the player
   - Cleans up all cattle entities and AI cowboys

3. **Server-Side Tracking**:
   - Records failed missions in the database
   - Updates player statistics (failed_deliveries counter)
   - Marks contract status as 'failed'

4. **Database Changes**:
   - Added `failed_deliveries` column to `tlw_cattle_players` table
   - Existing contracts table already supports 'failed' status

## Installation

### For New Installations
Simply run the updated `sql/install.sql` which now includes the `failed_deliveries` column.

### For Existing Installations
Run the migration script:
```sql
-- Run this in your database
source sql/add_failed_deliveries.sql
```

Or manually execute:
```sql
ALTER TABLE `tlw_cattle_players` 
ADD COLUMN IF NOT EXISTS `failed_deliveries` INT NOT NULL DEFAULT 0 AFTER `perfect_deliveries`;
```

## Testing

### Manual Testing Steps
1. **Start a cattle herding mission**:
   - Go to a buy location (Emerald Ranch or McFarlane's Ranch)
   - Purchase cattle (5 recommended for testing)

2. **Test the safety feature**:
   - While the cattle are active, shoot one of your own cattle
   - **Expected Result**: Mission should immediately fail with messages:
     - "⛔ MISSION FAILED: You killed your own cattle!"
     - "Your contract has been terminated."
   - All cattle should be cleaned up
   - Contract should be marked as 'failed' in database

3. **Verify database tracking**:
   ```sql
   -- Check player stats
   SELECT citizenid, failed_deliveries, cattle_lost 
   FROM tlw_cattle_players 
   WHERE citizenid = '<your_citizenid>';
   
   -- Check contract status
   SELECT status, cattle_type, herd_size, started_at 
   FROM tlw_cattle_contracts 
   WHERE citizenid = '<your_citizenid>' 
   ORDER BY started_at DESC LIMIT 5;
   ```

4. **Test normal gameplay still works**:
   - Start another mission
   - Herd cattle normally without killing them
   - Sell successfully to verify normal flow isn't affected

### Edge Cases Tested
- Player shooting cattle directly
- Player's mount trampling cattle
- Cattle dying from other causes (should NOT fail mission):
  - Rustler attacks
  - Environmental hazards
  - Predator attacks
  - Natural wandering/straggling

## Configuration

The failure messages can be customized in `config.lua`:
```lua
Config.Messages = {
    mission_failed = "⛔ MISSION FAILED: You killed your own cattle!",
    mission_failed_subtitle = "Your contract has been terminated.",
}
```

## Technical Details

### Detection Method
The system uses FiveM/RedM natives:
- `GetPedSourceOfDeath()` - Identifies who/what killed the cattle
- `GetPedCauseOfDeath()` - Identifies weapon used
- `GetSelectedPedWeapon()` - Checks player's current weapon

### Performance Impact
- Minimal: Detection thread runs at 100ms intervals (10 times per second)
- Only active during an active herding mission
- Thread terminates when mission ends

### Security
- Server validates the contract token before marking as failed
- Prevents potential exploits through client manipulation
- All database operations are server-side

## Future Enhancements
Potential improvements for consideration:
- Configurable grace period (e.g., accidental shot doesn't immediately fail)
- Warning system (first offense = warning, second = failure)
- Damage threshold (minor damage OK, but killing = failure)
- Admin override to manually fail/unfail missions

## Support
If you encounter issues:
1. Check server console for debug messages (enable with `Config.Debug = true`)
2. Verify database migration was successful
3. Check that RSG-Core framework is up to date
4. Report issues with reproduction steps
