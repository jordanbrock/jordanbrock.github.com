---
layout: post
title: 2nd Gen Accelerators, Rails and attachment_fu
permalink: /2008/10/17/2nd-gen-accelerators-rails-and-attachment-fu/index.html
post_id: 350
categories: 
- accelerator
- Development
- joyent
- rails
- Ruby On Rails
- rubyonrails
- Tech
---

File this one under <span class="caps">WTF</span>.

I've been working on an updated version of the <a href="http://www.soilquality.org.au">Soil Quality</a> website for a little while now, and recently needed to deploy the site to a staging server for testing. I ordered up a <a href="http://www.joyent.com/accelerator/">1/4Gb Accelerator</a> from <a href="http://www.joyent.com">Joyent</a>, configured it, and <a href="http://wiki.joyent.com/accelerators:deploying_rails_apps">deployed</a> the app, just like I've done with 20+ other sites, and <span class="caps">BOOM</span>, straight into a brick wall.

I opened up the log files and saw this error:

{% highlight bash %}
** Daemonized, any open files are closed.  Look at /tmp/soilquality-mongrel.8200.pid and log/mongrel.8200.log for info.
** Starting Mongrel listening at 127.0.0.1:8200
** Define INLINEDIR or HOME in your environment and try again
{% endhighlight %}

Wonderfully descriptive I know, but something I'd never run into before. So, fire the the google and it turns out it's a common error, with a common fix: just put

{% highlight ruby %}
ENV['INLINEDIR'] = RAILS_ROOT + "/tmp"
{% endhighlight %}

into your config/environment.rb file, make sure the directory exists and that it's writeable by the mongrel, restart, and away you go.

But of course, that didn't fix it, did it.

Much hair pulling ensued. I finally enlisted the help of <a href="http://blog.ninjahideout.com/">Darcy Laycock</a> and together we managed to track the problem down to the <a href="http://github.com/technoweenie/attachment_fu/tree/master">attachment_fu plugin</a>, which was causing the problem as the mongrel process booted. OK, so now we knew where the problem lay, but what was causing it.

It turned out to be the ImageScience image processor, or more specifically the way the attachment_fu plugin and ImageScience work together *<span class="caps">ON A 2ND GENERATION JOYENT ACCELERATOR</span>* - eg the ones that use pkgsrc. Didn't seem to cause the problem on an ubuntu machine, nor on one of the older BlastWave based Accelerators. I'm not sure why as of yet, as I was more worried about getting some sleep last night when we managed to fix the problem.

And the fix? Basically, strip ImageScience out of attachment_fu. Remove

{% highlight ruby %}
vendor/plugins/attachment_fu/lib/technoweenie/attachment_fu/processors/image_science_processor.rb
{% endhighlight %}

and remove "ImageScience" from this line

{% highlight ruby %}
default_processors = %w(ImageScience Rmagick MiniMagick Gd2 CoreImage)
{% endhighlight %}

in this file
<pre>vendor/plugins/attachment_fu/lib/technoweenie/attachment_fu/attachment_fu.rb</pre>

Like I said, I have no real idea why this is happening at the moment, but I'll try and work it out and update this post if I get anywhere.

Once again, thanks to Darcy for A) being a sounding board, B) helping fix the problem and C) being up and available when I needed him :)

