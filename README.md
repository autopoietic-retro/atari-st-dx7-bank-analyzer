# atari-st-dx7-bank-analyzer
Accessory Multi Bank Loader, sound documentor and comparison, ST-Pascal

You can load this like any ACC, run Notator or something similar, pick the accessory from the system menu,
and you get a text mode interface that can switch banks and send sounds at keypress.
It can load 8 banks from disk. You can drop banks from memory.
Play with the menus. It sends banks to the synth, also single, unpacked sounds. This is transparent.
Do "B312" and it will send the sysex for sound 12 from bank 3.
It can also receive sound banks.
Probably you have to initiate a send from the synth menus, after you put the ACC into wait-for-receive mode.
(DX-7II extra functions not supported, but it loads.)

You can move sounds between banks and save a changed bank.
You can print out the detailed sound data, and you can compare two sounds that you pick from the sound listings.
Move the cursor up and down, left and right, with the arrow keys. At that point, <ENTER> sends the sound.
Some features use the cursor and then a key command and maybe a sound number.

Bear with me, it has been a long time, and it is hard to remember.
But I know that the directory functions should be improved, because it was built only with a diskette in mind.
Have a lot of fun!
