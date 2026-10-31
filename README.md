# atari-st-dx7-bank-analyzer
Accessory Multi Bank Loader, sound documentor and comparison, ST-Pascal

You can load this like any ACC, run Notator or something similar, pick the accessory from the system menu,
and you get a text mode interface that can switch banks and send sounds at keypress.
It can load 8 banks from disk. You can drop banks from memory.

Play with the menus. It sends banks to the synth, also single, unpacked sounds. This is transparent.
Do "B312" and it will send the sysex for sound 12 from bank 3.

It can also receive sound banks:
Probably you have to initiate a send from the synth menus, after you put the ACC into wait-for-receive mode.
(DX-7II extra functions not supported, but it loads.)

You can move sounds between banks and save a changed bank.
You can print out the detailed sound data, and you can compare two sounds that you pick from the sound listings.
Move the cursor up and down, left and right, with the arrow keys. At that point, ENTER sends the sound.
Some features use the cursor and then a key command and maybe a sound number.

To compare 2 sounds, enter the bank manager.
Press X to start. You will see 2 banks that you have selected previously.
It asks you to select the first sound. Navigate with the arrow keys, then press ENTER.
It asks you to select sound #2. Do the same. Pick any sound from the two banks.
After selection, the screen will show you the parameters of the two sounds, one below the other.
The top line of each parameter sheet will show you the names of the sound and bank

Bear with me, it has been a long time, and it is hard to remember.
But I know that the directory functions should be improved, because it was built only with a diskette in mind.

Try both similar acc files, and tell me which one works.

Other files:
A couple of PNG screen shots.
MIDI.INC is historical, not needed to compile this version.
Banks:
I included some banks as test data for educational purpose.
The license does NOT apply to the banks.
Some are my sounds, many are "abandonware" floating around the web.
(Sounds I seem to remember as mine: .PRINCEORG, DUALMATRIX, FLUGEL--8J, some others from MU2.BNK)

Have a lot of fun!
