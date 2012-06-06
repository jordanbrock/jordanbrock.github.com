---
layout: post
title: Getting Rails, Git and Capistrano to work on a Joyent Accelerator
permalink: /2008/04/08/getting-rails-git-and-capistrano-to-work-on-a-joyent-accelerator/index.html
post_id: 331
categories: 
- accelerator
- capistrano
- Development
- git
- github
- joyent
- programming
- Ruby On Rails
- rubyonrails
- Tech
---

p. After several days of repeatedly smashing my head into both a metaphorical and an all too real brick wall, I seem to have managed to get <a href="http://git.or.cz">git</a> and <a href="http://capify.org">capistrano</a> working happily together on my <a href="http://www.joyent.com/accelerator">Joyent Accelerator</a>. I'm also using <a href="http://github.org">github</a> for my git hosting, which threw up it's own little challenge mid-way through the entire process.




	p. Now, I should probably also say that I already had my site up and running using subversion, capistrano and my accelerator, so this article isn't necessarily going to help with getting everything setup the first time. For that, you probably need to read this <a href="http://wiki.joyent.com/accelerators:deploying_rails_apps">wiki entry</a>.




	h3. Things You Will Need




	<ul>
	<li>A github.org account</li>
		<li>A dedicated Joyent Accelerator (I have no idea how to do all of this on a shared accelerator. Sorry.)</li>
		<li>Also, I'm really only talking about RubyOnRails apps here ... not too sure how applicable a lot of this is to other frameworks (it will probably help at least.)</li>
	</ul>


	h3. Getting started




	p. Assuming that you have your project in a git repository, and have a <a href="http://github.org">github</a> account (and obviously an Accelerator) we can start.




	h4. Compiling git on your accelerator




	p. Unfortunately, the first step in the process was, for me at least, a total nightmare. I'm not the biggest unix-head by any stretch, but I can do some basic tasks with a degree of proficiency. Unfortunately, I went into a dark place trying to get git compiled. One thing to note is that I'm talking about setting up the git client here, not a git server. Because capistrano executes scripts on your remote server, you need to have a copy of the client software setup for capistrano to call.




	p. So what did I do? There are a couple of helpful threads on the Joyent Forums:




	<ul>
	<li><a href="http://discuss.joyent.com/viewtopic.php?id=22094">Got git?</a></li>
		<li><a href="http://discuss.joyent.com/viewtopic.php?pid=175313">Git and Cap 2.0</a></li>
		<li><a href="http://discuss.joyent.com/viewtopic.php?pid=177469#p177469">Installing git</a></li>
	</ul>


	p. Hopefully those threads will put you onto the path of successfully compiling and installing git onto your Accelerator.




	h4. Setting up <span class="caps">SSH</span> keys with github and your accelerator




	p. When you setup your account on github, you need to setup an <span class="caps">SSH</span> key for authentication. github has a <a href="http://github.com/guides/providing-your-ssh-key">really good tutorial</a> on how to do this. I have a user defined on my accelerator that my website "runs" under, so what I did was to create a key for that user which gets stored into the ~/.ssh directory. I then added the contents of the id_rsa.pub key to my github account, which allows that user to access the repository.




	p. Another tip: don't forget your passphrase. It's needed in the next step.




	h4. Configuring capistrano




	p. Assuming that you have your capistrano deploy.rb file setup as outlined <a href="http://wiki.joyent.com/accelerators:deploying_rails_apps">here</a> there are a few changes that you will need to make to get things working with git.




	p. _I'm using Capistrano 2.2 at the moment. I don't think it will work with earlier versions because of the relatively new git support._




	p. Here's my deploy.rb file:




<pre>
  require 'erb'
  require 'config/accelerator/accelerator_tasks'

  set :application, "website" 
  set :repository, "git@github.com:your_username/website.git" 

  default_run_options[:pty] = true
  set :domain, 'XX.XX.XX.XX' #Your Accelerators public IP address
  set :deploy_to, "/var/www/apps/#{application}" 
  set :user, 'website_account_username'
  set :scm, :git
  set :scm_username, "github_username" 
  set :scm_passphrase, "your passphrase here" 

  role :app, domain
  role :web, domain
  role :db,  domain, :primary => true

  set :server_name, "url.for.website" 
  set :server_alias, "*.url.for.website" 

  # Example dependancies
  depend :remote, :command, :gem
  depend :remote, :gem, :money, '>=1.7.1'
  depend :remote, :gem, :mongrel, '>=1.0.1'
  depend :remote, :gem, :image_science, '>=1.1.3'
  depend :remote, :gem, :rake, '>=0.7'
  depend :remote, :gem, :BlueCloth, '>=1.0.0'
  depend :remote, :gem, :RubyInline, '>=3.6.3'

  ################################
  # Some tasks for the old server
  ################################

  task :after_deploy do
    # tasks to run after deploy
  end

  ################################
  # End tasks for the old server
  ################################

  deploy.task :restart do
    accelerator.smf_restart
    accelerator.restart_apache
  end

  deploy.task :start do
    accelerator.smf_start
    accelerator.restart_apache
  end

  deploy.task :stop do
    accelerator.smf_stop
    accelerator.restart_apache
  end

  after :deploy, 'deploy:cleanup'
</pre>

	p. It appears that the important line here is '  default_run_options[:pty] = true '. This means that capistrano can respond automatically for the request for the <span class="caps">SSH</span> Key passphrase that github replies with when you try to clone the repository.




	p. If everything is working, you can type &#8216;cap deploy' and it should all deploy nicely. If you get this error:




@
  [err] Permission denied (publickey).
@

	p. then there's a problem with your <span class="caps">SSH</span> key and your settings on github. Make sure the key you copied into your github account is the public key for the <span class="caps">SSH</span> in your .ssh directory.




	p. Hopefully, you'll be up and running. If you have any tips, recommendations or corrections, leave a comment.

