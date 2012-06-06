---
layout: post
title: Vagrant + Chef (and OpenPhoto)
permalink: /2012/04/17/vagrant-chef-and-openphoto/index.html
post_id: 516
categories: 
- Development
- Tech
- Web
---

I've spent the past couple of days playing with <a href="http://www.vagrantup.com" target="_blank">Vagrant </a>, which is an add-on for <a href="http://www.virtualbox.org" target="_blank">VirtualBox</a> that allows you to quickly build virtual machines, configured exactly how you want them, on a project by project basis. The advantage of this is that it lets you replicate your production environment (or as close to as is possible), which should hopefully reduce headaches when you deploy your updates. 

Vagrant VM's are portable, which means that all of your team members can have exactly the same development environment, regardless of their own system setups. Once again: less headaches.

h3. Vagrant

How does it work? Well, first of all, you need the <a href="https://www.virtualbox.org/wiki/Downloads">latest version of VirtualBox</a>, and the vagrant gem. I installed it into my system gems, but there's no reason it couldn't be in your Gemfile if you're working on a ruby project.

{% highlight bash %}
gem install vagrant
{% endhighlight %}

Once it's all setup (read the <a href="http://vagrantup.com/docs/getting-started/index.html" target="_blank">full instructions</a> for some additional steps), you need to initialise your directory:

{% highlight bash %}
vagrant init
{% endhighlight%}

This creates a file called "Vagrantfile" which configures your VM's for each project. The most basic file would look like this:

{% highlight ruby %}
Vagrant::Config.run do |config|
  config.vm.box = "lucid32"
end
{% endhighlight %}

This tells vagrant to start up a VM using an Ubuntu image. It will boot the VM, and then set a port redirect up so that you can SSH into the VM with the following:

{% highlight bash %}
vagrant ssh
{% endhighlight %}

That's all very handy, but of course, you're going to want your machine to have some software configured. Enter Chef, stage left.

h3. Chef

<a href="http://wiki.opscode.com/display/chef/Home" target="_blank">Chef</a> is a framework that lets you create "recipes" to install and configure software on VM's. Basically, it's a scripting system for getting a blank VM up and running. 

As a good starting point, Opscode have a <a href="https://github.com/opscode/cookbooks/">great repository</a> of "cookbooks" (collections of recipes - natch) on github that you can fork and start using without having to make too many (if any) changes.

To work with Vagrant and Chef, you need a VM configured for Vagrant with a recent build of Ruby installed, as well as the chef. Setting up an Ubuntu 11.10 VM for Vagrant is relatively simple. Just follow steps 1-3 in <a href="http://www.yodi.me/blog/2011/10/26/build-base-box-vagrant-ubuntu-oneiric-11.10-server/">these instructions</a>.

Once that was complete, you need to install Ruby. Here's a <a href="http://boris.muehmer.de/2012/03/18/ruby-1-9-3-p125-from-source-on-ubuntu-10-04-lts/">quick guide</a> to installing Ruby 1.9.3-125 from source on Ubuntu.

Then I installed the chef gem

{% highlight bash %}
gem install chef
{% endhighlight %}

to get chef-client and chef-solo on the VM. _(Note: I'm only dealing with chef-solo in this post. chef-server adds a layer of difficulty that isn't necessary at this stage.)_

Once you have your base VM setup, you need to package it up for Vagrant, so it can load it up in VirtualBox as needed. 

{% highlight bash %}
mkdir ~/Vagrant && cd ~/Vagrant

vagrant package --base vagrant-oneiric package.box

vagrant box add vagrant-oneiric package.box 
{% endhighlight %}

At this point, you should have a base VM ready for configuring with Chef.

h3. Vagrant and Chef, sitting in a tree

Vagrant is built to work with provisioning software such as Chef (and <a href="http://puppetlabs.com/">puppet</a>). You add a series of Chef commands to your Vagrantfile that it will run on your VM as it is being configured. 

To add recipes to your VM you just add the following to your Vagrantfile:

{% highlight ruby %}
chef.add_recipe("mysql::server")
{% endhighlight %}

Chef allows for configuration settings, such as passwords and installation directories, to be passed through to recipes. Vagrant supports this as well:

{% highlight ruby %}
config.vm.provision :chef_solo do |chef|
  chef.json = {
    :mysql => {
      :server_root_password => "secretpassword"
    }
  }
  chef.add_recipe("mysql::server")
end
{% endhighlight %}

h3. OpenPhoto

OpenPhoto is an open source photo service that allows you to retain control of your photos, rather than store them with some site that may not even exist in 3 years. Your photos are stored on AmazonS3 or on Dropbox, and you can run a server yourself to maintain total control over the whole setup if you wish, or use their hosted service available here: <a href="http://openphoto.me">http://openphoto.me</a>.

Being open source, anyone can contribute to the system, and as with most open source projects, they need as much help as they can get. So, I've started tinkering with it, and I thought it was a good candidate to run with Vagrant and Chef to setup test servers quickly and painlessly.

So, if you want to do the same, here's my Vagrantfile for my OpenPhoto directory, which is a git clone of my fork of the <a href="https://github.com/openphoto/frontend">OpenPhoto repository</a> on github. It should hopefully allow you to get up and running if you've done everything outlined above.

{% highlight ruby %}
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::Config.run do |config|
  config.vm.box = "vagrant-oneiric"

  config.vm.provision :chef_solo do |chef|
    chef.binary_path = "/path/to/chef/binary/"
    chef.cookbooks_path = "/path/to/chef/cookbooks"

    chef.json = {
      :mysql => {
        :server_root_password => "secretpassword"
      }
    }

    chef.add_recipe("mysql")
    chef.add_recipe("mysql::server")
    chef.add_recipe("apache2")
    chef.add_recipe("imagemagick")
    chef.add_recipe("php")
    chef.add_recipe("php::module_curl")
    chef.add_recipe("php::module_mysql")
    chef.add_recipe("php::module_apc")
    chef.add_recipe("php::module_dev")
    chef.add_recipe("php::module_imagick")
    chef.add_recipe("php::module_mcrypt")
    chef.add_recipe("php::module_gd")
    chef.add_recipe("apache2::mod_rewrite")
    chef.add_recipe("apache2::mod_deflate")
    chef.add_recipe("apache2::mod_headers")
    chef.add_recipe("apache2::mod_expires")
    chef.add_recipe("apache2::mod_php5")
    chef.add_recipe("git")
  end

  config.vm.share_folder "openphoto", "/var/www/openphoto", "/path/to/openphoto/frontend", :owner => "www-data", :group => "vagrant"

  config.vm.forward_port 80, 8080
end
{% endhighlight %}

Run 

{% highlight bash %}
vagrant up
{% endhighlight %}

and that will build your new VM using the base image, and then configure all of the required software. It might take a little while :)

One of the great things about Vagrant is that you can quickly share folders with your VM, which means I can edit files in my repository on my Mac, which are shared onto the VM. This is accomplished with this line:

{% highlight ruby %}
config.vm.share_folder "openphoto", "/var/www/openphoto", "/path/to/openphoto/frontend", :owner => "www-data", :group => "vagrant"
{% endhighlight %}

h4. Apache

You'll also need to configure Apache to use this directory. Here's my config file:

{% highlight apache %}
<VirtualHost *:80>
  DocumentRoot /var/www/openphoto/src/html

  <Directory "/var/www/openphoto/src/html">
    Order deny,allow
    Allow from all

    RewriteEngine on
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule ^(.*)\?*$ index.php?__route__=/$1 [L,QSA]

    # 403 Forbidden for ini files
    RewriteRule \.ini$ - [F,NC]

    AddOutputFilterByType DEFLATE text/plain
    AddOutputFilterByType DEFLATE text/html
    AddOutputFilterByType DEFLATE text/css
    AddOutputFilterByType DEFLATE application/x-javascript
    BrowserMatch ^Mozilla/4 gzip-only-text/html
    BrowserMatch ^Mozilla/4\.0[678] no-gzip
    BrowserMatch \bMSIE !no-gzip !gzip-only-text/html 
  </Directory>

  # 404 Not Found for ini files
  #AliasMatch \.ini$    /404

  ExpiresActive On
  ExpiresByType text/javascript "A31536000"
  ExpiresByType application/x-javascript "A31536000"
  ExpiresByType text/css "A31536000"
  ExpiresByType image/x-icon "A31536000"
  ExpiresByType image/gif "A604800"
  ExpiresByType image/jpg "A604800"
  ExpiresByType image/jpeg "A604800"
  ExpiresByType image/png "A604800"
  
  Header set Cache-Control "must-revalidate"
  FileETag MTime Size
</VirtualHost>
{% endhighlight %}

You can then add a port forwarding rule to provide easy access to the Apache server running on the VM, like so:

{% highlight ruby %}
config.vm.forward_port 80, 8080
{% endhighlight %}

Then, fire up "http://localhost:8080" in your browser, and you should be looking at your OpenPhoto install!

