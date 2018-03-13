---
layout: post
title: Maps, Geocoding and Great Timing
permalink: /2007/02/10/maps-geocoding-and-great-timing/index.html
post_id: 262
categories: 
- Development
- geocoding
- programming
- ruby
- Ruby On Rails
- rubyonrails
- Web
---

 On one of the sites I've been working on for quite a while (<a href="http://www.schoolseek.com.au">SchoolSeek</a>) we've been wanting to add the ability for users to find out how far a school is from their current location. There are services that have been able to <a href="http://en.wikipedia.org/wiki/Geocode">geocode</a> addresses for a while, but they were either based in the US, or cost money. Not a lot of money, but free is always good.




A couple of years ago, <a href="http://maps.google.com">Google Maps</a> launched in the US and opened up a massive range of possibilities for programmers to develop cool "mashups", which took information from one site, mashed it together with maps from google, and created a whole new website. They were all really cool, but unfortunately (at least for the non-US based of us) it was nothing more than something we could sit back and watch - which was kind of weird because the team of developers that built Google Maps was based in Sydney.




But <a href="http://googleblog.blogspot.com/2006/05/on-map-down-under.html">finally</a> the Australian version of google maps was released, and then recently integrated with Local Search, which means you can search on Pizza shotps near a particular address. Which is cool.




What is even cooler (if you're a ruby developer), though, is the release of this: <a href="http://geokit.rubyforge.org/">GeoKit</a>. It integrates with all of the major geocoding/mapping services and provides a huge range of options and services. So now you can do stuff like this:




<pre>
add_1=GeoKit::Geocoders::GoogleGeocoder.geocode("1 St Georges Terrace, Perth, Western Australia")
add_2=GeoKit::Geocoders::GoogleGeocoder.geocode("1 York St, Albany, Western Australia")

distance = add_1.distance_from(add_2, :units => :kms)
</pre>

Which returns




@
389.248018478531
@

which is, of course, how far it is between the main streets of Perth and Albany in Western Australia.




Sawwweeeeeet.




### Update




Well, that didn't take long at all. A quick loop over the existing schools in the <a href="http://www.schoolseek.com.au">SchoolSeek</a> database got the lat/long information for all the addresses. Then adding this line




<pre>acts_as_mappable default_units => :kms</pre>

to my Address model allows you to do this




<pre>
@addresses = Address.find(:all, :origin => "18 Bland St, Ashfield, New South Wales", :conditions => "distance < 10")
</pre>

which gives me all of the addresses within 10Kms of 18 Bland St, Ashfield. Nice.




So, basically GeoKit let me add distance searching to the site within about 45 minutes (allowing 25 minutes for me to read through the examples and such!)

