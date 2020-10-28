# ActionBarSaver by Aunion
This addon is based on the ActionBarSaver addon created by Shadowed103, which was last updated in 2014 for Warlords of Draenor. I have updated it to work with Shadowlands and rewritten and improved a lot of the functionality of the original addon.

ActionBarSavar is an addon that lets you save your current action bar mappings and then restore them at will. I've found this functionality especially useful when playing several characters of the same class, but I guess it could also be used for different talent builds.

## Commands
All commands start with the command `/abs`. By typing that into the chat you will get a list of other commands in game.

### SAVED PROFILES
* `/abs save <profile>` - Saves your current action bar setup to the specified profile.
* `/abs restore <profile>` - Restores your action bars to the specified profile.
* `/abs softrestore <profile>` - Restores your action bars to the specified profile. Soft restore will only add saved buttons, not empty buttons that have no value saved to them.
* `/abs delete <profile>` - Deletes the specified profile.
* `/abs rename <oldProfile> <newProfile>` - Renames a saved profile from oldProfile to newProfile.
* `/abs macro` - A settings which tells ABS to attempt to restore any macros that don't exist or have been deleted when restoring a profile. Off by default.
* `/abs list` - Lists all saved profiles.

### LINKED SETS
Linked sets allow you to add several abilities to a list of linked abilities, and if one of those abilities is listed in a profile but not available to your character, it will try to find another one from that list to use instead. Especially useful for racial abilities, if you have more than one character of the same class, but of different race.
* `/abs linknew "<spell>"` - Creates a new linked set with the specified spell, INCLUDE QUOTES, e.g "War Stomp".
* `/abs linkadd <linked set> "<spell>"` - Adds spell to a linked set, by specifiying the linked set with an integer and the spell within quotes; e.g to add War Stomp to set 1, write `/linkadd 1 "War Stomp"`.
* `/abs linklist` - Lists all linked spells.
* `/abs linkdelete` - Deletes either a linked set, or an item from a linked set. To delete the first set write `/linkdelete 1`, to delete the first spell from the first set, write `/linkdelete 1 1`.
