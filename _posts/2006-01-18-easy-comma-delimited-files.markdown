---
layout: post
title: Easy comma delimited files
permalink: /2006/01/18/easy-comma-delimited-files/index.html
post_id: 226
categories: []

---

p. From <a href="http://habtm.com/articles/2006/01/18/insta_export">~:caboose</a>




<pre>
  # this is used directly on models only
  # Usage: Customer.to_tab_delimited
  def self.to_tab_delimited(path = nil, columns = nil, options = nil)
    columns ||= self.column_names
    File.open(File.expand_path(path || "./#{table_name}.txt", RAILS_ROOT), 'w') do |file|
      file.puts(columns.join("\t"))
      # Notice this is very close to what the Array#to_tab_delimited below does, except Array only calls itself, meaning
      # it only exports it's own contents. 
      self.find(:all, options).each do |rec| 
        row = columns.inject([]) do |arr, col|
          if rec[col].is_a?(String)
            arr << rec[col].gsub(/[\t\n]/, ' ')
          else
            arr << rec[col]
          end
        end
        file.puts(row.join("\t"))
      end
    end
  end
end
</pre>