---
layout: post
title: Connecting to Joyent Accelerator with CocoaMySQL
permalink: /2007/11/15/connecting-to-joyent-accelerator-with-cocoamysql/index.html
post_id: 302
categories: 
- accelerator
- cocoamysql
- Development
- hosting
- joyent
- mysql
- Ruby On Rails
- ssh
- tunnels
- Web
---

 First things first: What's an accelerator? And why would you care about connecting to it with CocoaMySQL?




Well, basically, an <a href="http://joyent.com/accelerator/">accelerator</a> is kind of like a virtual server, offered by <a href="http://joyent.com">Joyent</a>. Calling it a virtual server is a bit of a misnomer, because it conjures up images of a linux slice, but it's a bit more than that. Running on OpenSolaris, it's built from the ground up to offer scalable hosting. You get root access, and the ability to do pretty much whatever you want with it. Out of the box, they are setup to be rather special RubyOnRails/PHP/Python servers, with mySQL all setup and running like a champ.




OK. So where does <a href="http://cocoamysql.sourceforge.net/">CocoaMySQL</a> come in? Your accelerator comes with PHPmyAdmin configured by default, but sometimes you want a little more than that you know? And with an app like CocoaMySQL you get a sweet <span class="caps">GUI</span> to do all your admin tasks, and nice editing facilities.




Because of the security built into your accelerator, you can't connect to mySQL from anywhere but your server. Handy for preventing attacks, but slightly painful for server management. So, you need to open up an <span class="caps">SSH</span> tunnel, to securely connect to the server. But first of all you need to make some configuration changes on your accelerator.




<pre>sudo nano /etc/ssh/sshd_config</pre>
change the following parameters to &#8216;yes'
<pre>
AllowTcpForwarding yes
GatewayPorts yes
</pre>

Then you need to restart the ssh daemon, with the following command
<pre>sudo svcadm restart svc:/network/ssh:default</pre>

The next step is to setup an "SSH tunnel" between your machine and the accelerator, which is basically a direct connection between the two machines. All traffic that flows along this connection is encrypted, reducing the ability for someone to sit there and listen in on what you're doing.




The command I use for setting up the tunnel is




<pre>ssh -2 -f -c blowfish -N -C username@accelerator.ip -L 3307/127.0.0.1/3306</pre>

This sets up a connection between port 3306 on the accelerator (specifically the mySQL port) and port 3307 on your local machine. To connect to your mysql server in CocoaMySQL you just connect to port 3307 on 127.0.0.1, which then just sends everything to your accelerator.




And a screenshot of the config screen for CocoaMySQL:




<img src="http://jordanbrock.com/assets/2007/11/15/cocoamysql_configuration.jpg" alt="" />




Now, obviously, that ssh command is going to be slightly painful to type in every time you want to connect to your accelerator. So, here's a <a href="http://textsnippets.com/posts/show/1254">handy dandy script</a> and configuration file that makes connecting to multiple servers a breeze. All you need to do is copy the setup in the config file and change the settings for each server. And of course, mirror those settings in CocoaMySQL.




_Thanks to <a href="http://www.cuddletech.com/blog/">Ben Rockwood</a> from Joyent for the <a href="http://forum.textdrive.com/viewtopic.php?pid=106780#p106780">tips on the config changes</a> needed on the accelerator_

