# dArkOS_Kiwix_Manager
Easily Serve your ZIMs on the Network from your R36S!

--Rough Steps--

Copy this script to your tools folder
Before running this on your R36S, make sure its connected to the internet!
When you first open tool, it will only say "install" if it doesnt find it already installed (installing only takes ~20-30 secs)
Once installed, it will auto search your sd cards 1 or 2 for zim files and list them here (I like to create a new folder called ZIMs on the easyroms partition and put them all in there to keep things neat)
At the top will tell you kiwix installed status, current ip and what zim is currently being served if any
Quitting out of the script while the zim is still running wont stop it from running
Can also stop hosting from within the script if you wanted

Note: It wont be able to start the kiwix server if remote services is running since that also starts a web server on port 80 which is what we are hoping to use. If you want to enable ssh server, you can do it after starting the kiwix server (just run remote services once kiwix is already serving)
