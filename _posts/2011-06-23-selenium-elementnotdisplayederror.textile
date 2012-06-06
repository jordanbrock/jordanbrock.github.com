---
layout: post
title: Selenium "ElementNotDisplayedError"
permalink: /2011/06/23/selenium-elementnotdisplayederror/index.html
post_id: 505
categories: 
- Development
- Ruby On Rails
---

If you do integration/request testing of an AJAXified web application using Rspec, Capybara and Selenium there is a pretty good chance that you might have run into this error:

{% highlight ruby %}
Selenium::WebDriver::Error::ElementNotDisplayedError:
Element is not currently visible and so may not be interacted with
{% endhighlight %}

After spending way too long to try and solve this problem ("THE ELEMENT *IS* VISIBLE DAMN YOU!!!!") I found a few little tweaks to my setup that help remove and/or mitigate the error.

The key to this error is that Capybara is trying to find and/or interact with an element and it's not quite ready on the page yet because some JavaScript hasn't executed yet, or there's a delay with the test web server.

h3. jQuery Effects


If you're running tests, there's a pretty good chance you don't care about any jQuery effects. You're just interested in the result. If that's the case, then add this line to your page layout:

{% highlight ruby %}
= javascript_tag '$.fx.off = true;' if Rails.env.test?
{% endhighlight %}

That will turn jQuery effects off in the Rails test environment.

h3. Capybara "wait_for"

This is a particularly helpful method that, like its name implies, causes Capybara to take a chill pill, and wait for a particular condition to be met. Call it like this:

{% highlight ruby %}
wait_for(15) {page.should have_content "Some text."}
wait_for(30) {page.should have_button "Button Text"}
{% endhighlight %}

This just gives the page a little time to catch up before Capybara blows up on you.

h3. capybara-webkit


A new Selenium driver from the fine folks at <a href="http://robots.thoughtbot.com/post/4583605733/capybara-webkit">Thoughtbot</a>, this is a headless (this just means it doesn't open a visible window) browser that Capybara can interact with. Ideally it should be faster than opening up a browser window for each test. I managed to get it working, mostly. It's still kind of new, so there are a few things missing, but it might be a good idea to watch the <a href="https://github.com/thoughtbot/capybara-webkit">github project</a>.
