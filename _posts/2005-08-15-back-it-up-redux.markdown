---
layout: post
title: Back it up (redux)
permalink: /2005/08/15/back-it-up-redux/index.html
post_id: 218
categories: []

---

 Further to my post the other day about <a href="http://www.strongspace.com" title="Strongspace" target="_blank">Strongspace</a>, backups and <a href="http://rsync.samba.org" title="rsync - data sync utility" target="_blank">rsync</a>, I thought I would just write a little bit about how I have everything setup, more for my own records than anything else. If the two other people who venture onto this page would like to read along then open your books to page one, and remember to turn the page when you hear the bell.

First of all, you need to get yourself a Mac. I'm serious about that. I've been a PC person all along but things just work better on MacOSX. It's true. I know it sounds a little like a reformed smoker, however, you should really give a Mac a go. Get a <a href="http://www.apple.com/macmini/" title="Apple MacMini - Oooh, so sexy!" target="_blank">MacMini</a>. They look sweet.

In order to connect to Strongspace, you need to have ssh on your computer. This comes standard with MacOSX, but you will have to download it for Windows. The best client that I have found is <a href="http://www.chiark.greenend.org.uk/~sgtatham/putty/" title="PuTTY: A free telnet/ssh client" target="_blank">PuTTY</a>. Download it (it's free), put it in your windows folder.

The next application you need is an <span class="caps">FTP</span> client that supports <span class="caps">SFTP</span>. The best (IMHO) windows free client is <a href="http://filezilla.sourceforge.net/" title="FileZilla - Fast, Reliable and Free" target="_blank">FileZillla,</a> and for MacOSX it's <a href="http://cyberduck.ch/" target="_blank">Cyberduck</a>.

Then (and this is the bit that I don't know how to replicate on Windows) you have to create some <span class="caps">SSH</span> public keys. We need to do this so that we can make connections to Strongspace without having to type in a password everytime we want to back some files up. There are instructions on how to do this on the <a href="http://www.strongspace.com/weblog/tips-and-tricks/using-ssh-keys-for-a-quick-sftp-login" title="Using SSH Keys for a Quick SFTP Login" target="_blank">Strongspace blog</a>. Essentially you need to create a public key and copy it up to a file called "authorized_keys" in a .ssh directory in your user directory on strongspace and then away you go. All very handy.

The next step is to write and test your rsync script. There are more options for rsync than I could ever learn, and also more functionality than I could write about, so I will just post the script I use. Basically it copies all data within my user directory, excluding directories that are listed in the "backup_excludes.txt" file and delete any files from the remote server that have been deleted from the local computer. Simple really:

<pre>#!/bin/sh
rsync -e ssh -azvC --delete --exclude-from backup_excludes.txt \
/Users/userdir/ username@username.strongspace.com:/home/username/

</pre>

The next step is to add a cron job to your computer. This is where the Mac part becomes pretty essential, because Windows doesn't have cron. It does have Task Scheduler, but I haven't been able to get that to run particularly reliably. In any case, an entry like the following will run your backup script every hour between the hours of 9AM and 10PM during the day.

<pre>01 9-22 * * * /Users/userdir/backup_documents
</pre>

Now this might seem like a lot to copy up, but that's the beauty of rsync. It only does incremental copying, so it will only copy files that have changed since the last time the script ran. Of course, if you work with video files, this might be overkill, because of the time it takes to upload the files, so you can adjust to your own needs.

rsync can also do standard weekly incremental backups, which is something I have yet to experiment with.

Like I said, this was mainly for my own records, but hopefully it will come in handy for someone.

*<span class="caps">UPDATE</span>*:
While trying to help <a href="http://dave.typepad.com/dave/2005/08/attn_applescrip.html#comments">Dave Caolo</a> it became apparent that I left one step out of the article ... installing <a href="http://www.sshkeychain.org/">SSHKeychain</a>. This freeware program waits on your computer for an <span class="caps">SSH</span> key request, intercepts that request and sends the required information, eliminating the need for you to have to type in your passphrase every time you try to backup your data, or <span class="caps">SFTP</span> into somewhere. It's very handy.

