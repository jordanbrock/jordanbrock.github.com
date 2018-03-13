---
layout: post
title: Setting up AutoTest on Mac OS  X
permalink: /2009/08/08/setting-up-autotest-on-mac-os-x/index.html
post_id: 468
categories: 
- Development
- Ruby On Rails
---

Another in the series of "Oh, I'd better write this down here so I don't forget it in the future" posts. This time, the gems needed to setup AutoTest for a rails app on Leopard

{% highlight bash %}
sudo gem install ZenTest   
 
sudo gem install autotest-fsevent 
 
sudo gem install autotest-rails  
 
sudo gem install redgreen
{% endhighlight %}

Then you need to create a ".autotest" file with the following:

{% highlight ruby %}
require 'autotest/fsevent'
require 'redgreen/autotest'
{% endhighlight %}

Then it's just a case of typing "autotest" in RAILS_ROOT.

Simple.
