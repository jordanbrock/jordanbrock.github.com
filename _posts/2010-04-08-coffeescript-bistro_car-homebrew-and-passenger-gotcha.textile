---
layout: post
title: CoffeeScript, bistro_car, homebrew, and passenger gotcha
permalink: /2010/04/08/coffeescript-bistro_car-homebrew-and-passenger-gotcha/index.html
post_id: 495
categories: 
- Development
- Ruby On Rails
---

File under "Things for me to remember when reinstalling stuff"

For me, one of the best things about using Ruby/Rails/Sinatra for web development is HAML/SASS, which allow me to quickly write and maintain HTML/CSS without having to worry about all the pointless stuff, like brackets etc. A by-product of using HAML/SASS is that when you have to write in something else, it causes me grief. JavaScript is a case in point.

Coffeescript (and to a lesser extent) bistro_car solve this. It brings the beauty of a ruby-like language to writing JavaScript, so that once again you don't have to worry about all the crap that goes along with it.

However, I ran into a slight problem when following <a href="http://drnicwilliams.com/2010/03/15/using-coffeescript-in-rails-and-even-on-heroku/">Dr Nic's setup tutorial</a> today. <a href="http://jashkenas.github.com/coffee-script/">CoffeeScript</a> worked, <a href="http://github.com/jnicklas/bistro_car">bistro_car</a> worked within the console, but it didn't work when accessing the page through the browser. But some path re-working, and a kind word or two from <a href="http://twitter.com/sutto">@sutto</a>, and we're good to go. 

For future reference, here's what I did. I'm using the <a href="http://github.com/mxcl/homebrew">homebrew package manager</a>. Mainly because it's awesome, and I use MacOS X, which is also awesome.

So, I installed node.js, coffeescript and bistro_car like so:

{% highlight bash %}
brew install node
brew install coffee-script
gem install bistro_car
{% endhighlight %}

Then, add the following to your environment.rb file:

{% highlight ruby %}
config.gem 'bistro_car'
{% endhighlight %}

Create an 'app/scripts' directory in your Rails app, which is where you can store all your .coffee files (application.coffee etc).

You then get bistro_car to include those script files by putting this in your layout/template/page/whatever:

{% highlight ruby %}
coffee_script_bundle
{% endhighlight %}

Then, you load the page, and bistro_car automagically uses coffee-script to convert your .coffee files to javascript. Except, of course, when it doesn't work because something is screwed somewhere.

As with almost every problem on a *nix computer, the problem is a path one, and thankfully solved with some simple symlinks. It seems <a href="http://www.modrails.com/">passenger</a> operates in it's own little world when it comes to paths, and it just didn't want to play nice with my environment. So, I tricked it as follows:

{% highlight bash %}
sudo ln -s /usr/local/bin/coffee /usr/bin/coffee
sudo ln -s /usr/local/bin/node /usr/bin/node
{% endhighlight %}

And that, my friend, is how you skin the unix path cat. 

