# [Arcade: Scramble](https://www.system16.com/hardware.php?id=554) port to [MiSTer](https://github.com/MiSTer-devel/Main_MiSTer/wiki)

MiSTer port by Sorgelig
Copyright (c) MikeJ - Feb 2007

## Description

A simulation model of Konami's Scramble hardware.

## Games

Currently implemented:

* Amidar
* Anteater
* Armored Car
* Battle of Atlantis
* Calipso
* Dark Planet
* Frogger
* Lost Tomb
* Mars
* Mighty Monkey
* Minefield
* Moonwar
* Rescue
* Scramble
* Speed Coin
* Strategy X
* Super Cobra
* Tazz-Mania
* The End
* Turtles

## Hiscore save/load

Save and load of hiscores is supported for the following games on this core:
 - Amidar
 - Anteater
 - Armored Car
 - Battle of Atlantis
 - Calipso
 - Dark Planet
 - Frogger
 - Lost Tomb
 - Minefield
 - Moonwar
 - Rescue
 - Scramble
 - Super Cobra
 - Tazz-Mania
 - The End
 - Turtles

To save your hiscores manually, press the 'Save Settings' option in the OSD.  Hiscores will be automatically loaded when the core is started.

To enable automatic saving of hiscores, turn on the 'Autosave Hiscores' option, press the 'Save Settings' option in the OSD, and reload the core.  Hiscores will then be automatically saved (if they have changed) any time the OSD is opened.

Hiscore data is stored in /media/fat/config/nvram/ as ```<mra filename>.nvm```

---------------------------------------------------------------------------------

## ROM Files Instructions

**ROMs are not included!** In order to use this arcade core, you will need to provide the correct ROM file yourself.

To simplify the process .mra files are provided in the releases folder, that specify the required ROMs with their checksums. The ROMs .zip filename refers to the
corresponding file from the MAME project.

Please refer to https://github.com/MiSTer-devel/Main_MiSTer/wiki/Arcade-Roms for information on how to setup and use the environment.

Quick reference for folders and file placement:

```
/_Arcade/<game name>.mra  
/_Arcade/cores/<game rbf>.rbf  
/_Arcade/mame/<mame rom>.zip  
/_Arcade/hbmame/<hbmame rom>.zip  
```
