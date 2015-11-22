# RenderFarm for Linux Networks

## Information

Was created to use Linux Clients in a school for rendering Blender Animations.
It is written in Perl and is using ssh to send the Data to the clients, and
to send the rendered images Back to the host via scp (ssh copy).

## The steps
1. Copy the *.blend File to the root Directory
2. Edit hosts.cfg
   There are the <hostnames> of the clients
3. Edit config.ini. Mostly the ssh Part.
```
[RenderFarm]
#Path that is created on the client
CLIENT_PATH=/RenderFarm/
#where do i store the rendered images
RENDER_PATH=images/
TMP_PATH=tmp/
#How much frames is the client rendering at once
DEFAULT_CHUNKS=5

#Things on the Host
#Where do i collect the rendered images on my host
COLLECT_PATH=collected/
#what is my ssh user
USER=root
#what is my ssh password
PASSWD=whatever
SCPFILE=scpBack.exp
```
4. Edit startRendering.sh and afterwards
```
perl RenderFarm.pl -file Baum1.blend -start 591 -stop 600 -chunk 3
```
start it `sh startRendering.sh`

5. After Rendering is finished, you can collect the Images with
```
collectImages.pl
```
This will also delete all data on the clients.
## Finally
This software can be improved, and will have some bugs. Right now its working.
So it is provided as it is. *Enjoy*
