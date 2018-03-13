---
layout: post
title: Gmail and MobileMe - Living Together in Perfect Harmony
permalink: /2008/07/15/gmail-and-mobileme-living-together-in-perfect-harmony/index.html
post_id: 343
categories: 
- Apple
- howto
- Tech
- Web
---
###_UPDATE_

_June 7, 2012_

_This article is now 4 years old, and as such, is quite out of date. Google have since provided instructions for setting up your iOS devices, and MobileMe is due to be switched off on June 30, 2012. I will leave this article up, but you shouldn't really follow any of the instructions any more!_

I've been using <a href="http://mail.google.com">Gmail</a> for about 4 years now, and it's pretty much become the centre of my email life, with my various email accounts being funneled into Gmail. I've used it with both the web client, and Mail.app on my Mac via <span class="caps">IMAP</span>, and have been pretty happy with both.

With the release of MobileMe and the iPhone 3G I made the decision to move to MobileMe (an Apple fanboi at heart, I wanted to keep it all within the one happy family - particularly seeing as work just bought me a MacBook Air.) But I was really reluctant to stop using Gmail as the repository of all of my email, both received and sent (awesome search, archiving and just to have a backup on another server).

It's relatively easy to setup forwarding from Gmail through to MobileMe, which you then add to your mail client (Mail.app on the Mac) and the mail will come in as per normal. But this would mean that any sent items won't appear in Gmail, which in turn means that Gmail is only storing half of the picture. But with <a href="http://twitter.com/adrianlynch">adrianlynch</a> doing most of the legwork, we were able to work out a solution.

There are quite a few little things that need to be done in order to fine tune the setup, particularly if you want to use multiple email addresses. I'll cover those, and then get to the meat of the setup.

###Multiple email addresses in Gmail.

Gmail has had the ability to support multiple email accounts for quite a while, and it all works quite well. First of all, sign into gmail, then go to the settings -> Accounts tab. The bet we're interested in is the "Send Mail As" bit. You can add all of the email addresses you want to have gmail send email for in here. Gmail will send a confirmation email to the address you enter (just to make sure that you are in fact billg@microsoft.com).

<img src="http://jordanbrock.com/assets/2008/7/15/Gmail_-_Settings_-_jordanbrock_gmail.com.jpg" alt="" />

###Setting up the email forwarding

There are two ways to forward email in Gmail. One is in the Settings -> Forwarding and <span class="caps">POP</span>/IMAP tab, which will forward every message to the address you specify. The other way is via a Filter (Settings -> Filters). I prefer to use the filter, because it allows me to get rid of some of the cruft mail that I don't really ever want to see again (eg, one of my mail accounts flags spam as ****SPAM**** ... if I didn't setup a filter to not forward this, I'd receive all of those emails in MobileMe, which is sub-obptimal to say the least).

<img src="http://jordanbrock.com/assets/2008/7/15/gmail_filter.jpg" alt="" />

##Setting up your computer

Of course, this assumes you're using a Mac. If not, I'm sure you're a smart enough person to work it out :)

###MobileMe setup

First up, add your MobileMe account. It's pretty simple. Just enter your MobileMe account details (same as your old .Mac account), and it should all be jake.

If you've setup gmail to handle multiple email addresses, enter them all in the "Email Address" field, separated by commas.

<img src="http://jordanbrock.com/assets/2008/7/15/email_addresses.jpg" alt="" />

###Gmail setup

Now, you need to add your gmail account to the system, as an <span class="caps">IMAP</span> account. Follow the instructions on <a href="http://mail.google.com/support/bin/answer.py?hl=en&ctx=mail&answer=12103">the Google Help Center</a>

Once you have added the account Mail.app will probably start downloading all of your mail from Gmail, which could take a fair while. This may or may not be something you want: your choice.

After the mail has all downloaded, go into the Advanced tab for the Gmail account in Mail.app, and uncheck "Enable this account."

<img src="http://jordanbrock.com/assets/2008/7/15/enable_this_account.jpg" alt="" />

Then, go back into your MobileMe account and set the outgoing <span class="caps">SMTP</span> server to smtp.google.com. All of your sent mail will now go through Gmail, which is great for archiving purposes. Because MobileMe is an <span class="caps">IMAP</span> server, it will automatically be copied up to the MobileMe server (because it's storing a copy in your Sent Items folder on your Mac), which means it's then available on all the computers you use MobileMe with, including your iPhone / iPod Touch.

###Why did I enter the multiple email addresses?

If you have multiple email addresses, and you entered them all in the "Email Address" box earlier, you will now have the option to choose which address to send your mail as when you create a new message.

<img src="http://jordanbrock.com/assets/2008/7/15/sending_message.jpg" alt="" />

There's one little gotcha here, and it's why I mentioned setting up the addresses from within gmail before. If you try to send a message from an email address that Gmail doesn't "know" about, it will replace the sender email with your Gmail address. This is obviously to stop you spoofing your address, but it took me a little while to work that bit out. So, just make sure that you've defined all the addresses that you want to "Send As"

##Setting up your iPhone / iPod Touch.

Once you have the above system up and working, you can basically mirror that setup on your iPhone. You need to create both accounts under "Mail, Contacts, Calendars" in the Settings application. Then disable the Gmail account, and set the outgoing <span class="caps">SMTP</span> server to gmail in the MobileMe setup.

<img src="http://jordanbrock.com/assets/2008/7/15/iphone_accounts.jpg" alt="" /> <img src="http://jordanbrock.com/assets/2008/7/15/iphone_gmail.jpg" alt="" /> <img src="http://jordanbrock.com/assets/2008/7/15/iphone_mobile_me.jpg" alt="" />

<img src="http://jordanbrock.com/assets/2008/7/15/iphone_push_it.jpg" alt="" />

If everything has gone according to plan, you should now have your Gmail "pushing" to your iPhone, and also appearing on your computer. And if you have multiple macs, and have sync turned on for "Mail Accounts" and "Mail Rules and Smart Folders", then you will shortly have those settings on both of your computers.

