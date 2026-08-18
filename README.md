8# Flashforge-creator-5-macros

# REQUIRED: Jailbreak!

# important: import [homing_ovveride] and comment [safe_z_home] before use tool macros.

Some macros to optimize creator 5 3d Printer

example: safe home, if you send a G28 command, and a hothend is mounted, now, the Creator make XY home, then leave the hothend on its plate,and only after, make also Z home, on original, the hothend crashed on bed if you sent G28 command from mainsail

another example, you can connect a hothend, cut filament and release the hothemnd in its deposit place, easy!!!!

and other some protection agants broken hothend on bed!

Load saved mesh calibration at start print, so you'll need onyl to save them for different bed temperatures, (macro saves mesh calld "50" for a bed that is from 50 to 59 degree, 60 for bed from 60 to 69 °C)

and at print start, it recall the right saved mesh based on bed target temp.

# OVVIAMENTE NON mi assumo nessuna responsabilità se l'uso di queste macro causa danni a cose o persone
