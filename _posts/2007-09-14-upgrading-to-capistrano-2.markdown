---
layout: post
title: Upgrading to Capistrano 2
permalink: /2007/09/14/upgrading-to-capistrano-2/index.html
post_id: 294
categories: 
- capistrano
- deploy
- Development
- Ruby On Rails
- rubyonrails
- snippets
- Web
---

 For no other reason than this is something I need to remember on other projects, here is a list of the changes I made when I uninstalled deprec and upgraded to <a href="http://capify.org">capistrano 2</a> for deployment.

### Things to do

Do this once

@
gem install mongrel_cluster
@

then in the application directory

@
capify .
@

then remove "require &#8216;deprec/recipes' from the deploy.rb file

then put the following in to the deploy.rb file

@
namespace :deploy do
  task :start,    :roles => :app do start_mongrel_cluster end
  task :stop,     :roles => :app do stop_mongrel_cluster end
  task :restart,  :roles => :app do restart_mongrel_cluster end
end
@
