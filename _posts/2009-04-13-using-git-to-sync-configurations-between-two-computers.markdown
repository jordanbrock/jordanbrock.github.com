---
layout: post
title: Using git to sync configurations between two computers
permalink: /2009/04/13/using-git-to-sync-configurations-between-two-computers/index.html
post_id: 359
categories: 
- Development
- git
- github
- macosx
- source control
- Tech
- zsh
---

I have two machines that I use for my development work: a 24" iMac and a MacBook Air (It is so choice. If you have the means, I highly recommend picking one up. _Bonus points for quote identification_). Naturally, doing any work spread over two machines leads to all sorts of problems: Inconsistencies in development platform, files, data, code and just the general configuration of the machine. Thankfully, there exists a number of solutions to these problems.

h3. <a href="http://www.getdropbox.com">DropBox</a>


DropBox is simply file synchronisation done right. You install it, drag the files you want to have synced between two computers into the Dropbox folder, and BOOM, it copies everything up to their server, and when you set it up on the second computer, copies everything back down again. After the initial sync, which can take quite a while if you've got lots of stuff, it's pretty much seamless. Create, or make a change to, a file on one computer, and before you know it, it's available on the other computer.

Need access to those files from another computer, or even from your phone? No problem, they have a web interface that give you full access to all of your "synced" files. Simple.

To add a lovely cherry to the ice cream sundae that is DropBox, they also have versioning. That means if you make a series of dunderhead changes to a document, you can just rollback to the last good copy. Awesome.

h3. <a href="http://git-scm.com/">Git</a> and <a href="http://www.github.com/">GitHub</a>


For the longest time (mostly while I was still working on Windows) "Source Control" was some mystical mumbo jumbo that only people in large companies needed to worry about. Of course, that was mainly because at the time the options for Visual Studio only included Microsoft SourceSafe, which is perhaps some of the crappiest, most unusable software ever foisted on the unsuspecting public by a company with a long history of foisting crap on the unsuspecting public.

Once I switched to MacOSX and started working with Rails, it became clear that all source control systems weren't created equally. Subversion seemed to be the choice of the community, so I loaded everything up onto my own SVN server. A world was opened up to me, and I could code with wild abandon, safe in the knowledge that I could rollback with no danger. Of course, that was the ideal world, but the basic approach worked. I created branches, tagged releases and deployed sites from SVN.

As with most things, people started grumbling about SVN and some of it's shortcomings: difficulties in merging different code branches, no distributed repositories and some general discontent. Git was the solution, and the rails community just jumped ships in the middle of the night. Before you knew it, everyone was using Git, and also GitHub. I won't go into the specifics of why this combo is so good, except to say that if you're not using git, well, good day to you sir.

h3. git and <a href="http://github.com/jferris/config_files/tree/master">config_files</a>


In addition to using git to store your development work, you can also use it to manage system configuration files. I found the wonderful <a href="http://github.com/jferris/config_files/tree/master">config_files</a>. It's a collection of shell, git, vim and irb configuration files. So? How does that help?

A great feature of git, and github in particular, is that you can "fork" a repository. You effectively copy someone else's repository, and you can then make all the changes to it you want, without affecting the original. If you want to let other people know about your changes, you can send the original developer a "pull request", and they can grab your changes, and incorporate them, or not.

So, fork the config_files repository, and then clone it to your own system. Run the "install.sh" script, which basically just sets up a series of symlinks in your user directory. These symlinks point to the files in the git repository. You make any changes you want to the repository and commit them up to github. Then do the same on your other computer, and bingo, you're synchronising your configuration between machines.

And why would you want config_files? Well, you get some great all round system setup tidbits, but my favourite bit is how it prints the current git branch as part of your prompt, saving you the need to try and work out what you're in the middle of doing.

Tasty.
