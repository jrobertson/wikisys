#!/usr/bin/env ruby

# file: wikisys.rb

require 'dxlite'

module Wikisys

  class Wiki

    def initialize(filepath='.', entries: 'entries.json', debug: false)

      @filepath = filepath
      @page = ''
      @debug = debug

      @entries = if File.exists?(entries) then
      
        DxLite.new(entries)

      else

        DxLite.new('entries/entry(title, tags)', filepath: entries)

      end
    
    end

    def page(title)

      r = @entries.find_by_title title   
      @page = r ? File.read(title + '.md') : make_page(title)

    end
    
    def page=(content)
      
      title = content.lines.first.chomp
      r = @entries.find_by_title title       
      make_page(title) unless r

      File.write title + '.md', content
      @page = content
      
    end    
    
    private
    
    def make_page(title)
      
      tags = title.downcase.gsub(/['\.\(\)]/,'').split.join(' ')
      s = "#{title}\n\n\n+ " + tags
      File.write title + '.md', s
      
      @entries.create title: title, tags: tags      
      @entries.save
      return s
      
    end
    
  end

end
