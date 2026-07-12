app requires shizuku, shows a floating toggle for choosing audio output between earphones and phone speaker,
toggle, pause music, resume, i think there should be no media playing on phone, so pause all

this is all ai slop

download the zip, inside this extracted zip, run build.sh for linux/macos or build.ps1 from windows powershell

ideally, the build scripts will see if u have openjdk and android commandlinetools installed, 
if not, they will download and install them in you rworking dir and temporarily change paths for your session
then they will download shizuku jars (the scripts dont check if you have them or not)
then they  will compile the java code, make apk, sign apk and clean up
if they dont work just ask some ai,
