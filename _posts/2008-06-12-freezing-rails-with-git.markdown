---
layout: post
title: Freezing Rails with Git
permalink: /2008/06/12/freezing-rails-with-git/index.html
post_id: 340
categories: 
- Development
- git
- rails
- Ruby On Rails
- rubyonrails
- Web
---

 Now that the Ruby On Rails team has moved the codebase over to <a href="http://github.com">github</a>, some of the standard rake tasks aren't working the way that they used to. When it was on <span class="caps">SVN</span>, it was possible to type

@rake rails:freeze:edge TAG=rel_2-0-1@

and the appropriate version would be copied into your vendor/rails directory.

Now if you do that, rake downloads a zip of the edge release. Which is fine and all, but sometimes you don't want to be on edge ... like in any production site.

So, I found a <a href="http://smartic.us/2008/5/15/freezing-rails-with-git">screencast</a> that goes through the process, but I thought I'd actually put the text into a post, mainly for my own reference more than anything else.

<pre>
$ rails path_to_app

$ cd path_to_app

$ git init

$ git submodule add git://github.com/rails/rails.git vendor/rails
</pre >

At this point, git will effectively clone the repository, so that you can then choose one of the branches to "freeze" to. Type "git tag" to get a list of all the available tagged branches. Choose the one you want and type

@$ git checkout v2.1.0@

And that's it. Slightly more involved than the old way, but still none too shabby.

