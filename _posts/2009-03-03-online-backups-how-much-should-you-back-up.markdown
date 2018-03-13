---
layout: post
title: "Online backups: How much should you back up?"
permalink: /2009/03/03/online-backups-how-much-should-you-back-up/index.html
post_id: 352
categories: 
- backups
- Development
- onlinestorage
- Tech
- Web
---

 Over the past few months, I have been slowly putting together a backup system that uses both local and online storage systems to provide a level of security and peace of mind.




##Backup Overview




 Using a combination of <a href="http://www.shirt-pocket.com/SuperDuper/SuperDuperDescription.html">Super Duper</a>, a couple of backup external <span class="caps">HDD</span>'s, <a href="https://www.getdropbox.com/">Dropbox</a>, <a href="http://www.jungledisk.com/">Jungle Disk</a> and <a href="http://aws.amazon.com/s3/">Amazon S3</a> I have built up what I think is a relatively comprehensive and reliable backup system.




###Local Backups




 SuperDuper is a wonderful program that creates bootable mirrors of a hard drive. Effectively what this means is that if a hard drive fails, you can just replace it with the backup copy. You can schedule the backups to run as often as you want, which ensures that your backup copy is fresh and useable in case of a disaster.




 And what am I backing up? I have two main drives that I use: The system disk (the built in drive in my iMac which contains all of my work files, personal documents, applications and the Operating System), and an external FireWire800 drive that stores photographs, videos, movies and TV shows.




###Amazon S3




 Amazon S3 is basically an online storage system that can be accessed via an <span class="caps">API</span> to upload, manage and retrieve data. Amazon charges for both the uploading of data (US$0.10 per Gb), and then for the actual storage of that data. The uploading charge is a one off cost, and the storage costs are charged monthly (US$0.15 per Gb per month).




###Jungle Disk




 One downfall of S3 is that it's not actually setup to be used without additional software to manage the mechanics of the backups. Step up Jungle Disk. It's pretty simple software: you give it your S3 account details, tell it what to backup, when to back it up and it will go ahead and take care of it for you. Simple. And then you get your monthly bill from S3. Nothing else to do.




 One big downside of the whole online backup setup is the time it takes to actually backup any large amount of data, and that's a limitation of my internet connection more than anything else. When you're uploading 100+Gb, be prepared for a bit of a wait :)




##The cost of Amazon S3




 While the monthly cost of the Amazon S3 service makes it a perfect online backup solution for data that you would class as priceless (photos, videos of the kids, work files, personal documents), when it comes to backing up stuff that can be easily replaced at a relatively low cost, such as iTunes TV shows and Movies, there soon comes a point where it's not actually economically feasible to use online storage.




###iTunes TV Shows




 The average 1 hour (42 minutes of network TV) HD episode of a TV show on iTunes is about 1.4Gb. In addition to this, you also get an iPod/iPhone compatible SD version which is generally 600Mb. So, a single TV show is effectively 2Gb of data that needs to be backed up.




 What is the cost of backing this file(s) up? Well, there's a US$0.20 charge for uploading it to Amazon S3 initially, and then a US$0.30 charge per month. At that rate, it only takes 10 months of storing the data online until you've actually paid for the file twice. This means that if you lost the original file 12 months after you first bought it, you'd actually be better off buying the file again.




 This effectively renders online backups for iTunes TV Shows pointless, considering how often you're actually likely to watch a TV show, and also how cheap the cost of having a local <span class="caps">HDD</span> mirror is.




###iTunes Movies




 Currently iTunes Movies are only available in SD (boo to the movie studios and Apple for this one) so the files aren't as large as they could be, but they're still pretty sizable, weighing in at 1.67Gb for the recent "The Dark Knight", which cost US$14.99. And how long until it's not feasible to store this on Amazon S3?




 At the purchase price, it would take 4.99 years until you've paid twice. However, Apple drops the price of new release films to $9.99 after about 4-6 months, so the replacement cost is greatly reduced. At this price the cut-off becomes 3.33 years. Obviously this timeframe requires a judgement call as to whether or not it's worth it. Personally, I'd rather just trust my local <span class="caps">HDD</span> backups.




###iTunes/Amazon Music




 Music files are obviously considerably smaller than video files, and as such are going to incur a greatly reduced monthly fee for storage. Your average iTunes album costs approximately US$9.99 and is generally around 110Mb. This small size means that it will actually take about 49.95 years until it's been paid for twice, buy which point you'll either be A) dead, or B) listening to music on your personal bone implant that plays whatever music you want that's being broadcast by SkyNet.




 So, music is one area where it's probably economical to maintain an online backup of your files, particularly considering how annoying it would be to go and re-purchase the 800+ albums you've got in your library in the first place.




##Other possible solutions and problems.




 Whenever you're talking about local <span class="caps">HDD</span> backups, it's always worth considering a <a href="http://www.drobo.com/">Drobo</a>, which is a redundant array of <span class="caps">HDD</span>'s that theoretically keeps your data happy and safe. I don't have a Drobo, but I know that users who have one swear by them.




 The one problem with local backups is that, of course, they are susceptible to local threats, e.g. fire and theft. There's no point in having duplicate hard drives that slavishly mirror each other if some reprobate comes along and pilfers them both. Which means you need a third mirror, that you store off-site. Which in turn means you need a fourth drive that you store off-site in rotation with the third one. An endless cycle.

