# Custom-Music-Discs-Minecraft-Datapack

To use create a folder called: `music`

Fill it with music in .ogg format and if you want distance to work, make sure its **mono** not **stereo**

Then run:

```
run.bat
```

You should see 2 folders generated:
- `cmd_dp`
- `cmd_rp`

1. Copy the `cmd_dp` to datapacks
1. Copy the `cmd_rp` to resourcepack


Internally the program creates an index of files, so if you add music into the `music` folder and rerun the program, updating the resourcepack and datapack will allow the old cds to work.

Also the code randomlly generates .pngs for each audio file that is generated. The same music file will always generate the same color disc.

**Limitations**, if you remove music the indexes will be messed up and old disks will no longer work.

Todo add a gui interface