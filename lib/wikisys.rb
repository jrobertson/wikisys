#!/usr/bin/env ruby

# file: wikisys.rb

require 'dxlite'
require 'martile'

module Wikisys

  class Wiki
    
    attr_reader :to_xml

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
      @page = r ? read_md(title) : make_page(title)
      @to_xml = build_xml @page
      @entries.save
      
      return @page

    end
    
    def page=(raw_content)
      
      title = raw_content.lines.first.chomp
      
      r = @entries.find_by_title title
      make_page(title, raw_content.lines.last.chomp[/(?<=\+ )/]) unless r
                   
      write_md title, raw_content
      
      @to_xml = build_xml raw_content      
      write_xml title, @to_xml

      
      @entries.save
      @page = raw_content
      
    end    
    
    private
    
    def build_xml(content)
      
      s = content.gsub(/\[\[[^\]]+\]\]/) do |raw_link|

        title = raw_link[2..-3].strip
        
        r = @entries.find_by_title title            
        
        e = Rexle::Element.new('a').add_text title
        e.attributes[:href] = title.gsub(/ +/, '_')
        
        if r then
          
          e.attributes[:title] = title.capitalize
          
        else
          
          make_page(title.capitalize)
          e.attributes[:class] = 'new'
          e.attributes[:title] = title.capitalize + ' (page does not exist)'
          
        end
                
        e.xml

      end         
      
      
      heading = "<heading>%s</heading>" % s.lines.first.chomp
      tags = ''
      
      if s.lines.last[0] = '+' then
      
        list = s.lines.last[2..-1].split.map {|tag| "    <tag>%s</tag>" % tag}
        tags = "<tags>\n%s\n  </tags>" % list.join("\n")
        
        body = "<body>\n    %s  </body>" % \
            Martile.new(s.lines[1..-2].join.strip).to_html
        
      else
        
        body = "<body>%s</body>" % Martile.new(s.lines[1..-1].join.strip).to_html

      end
            
      "<article>\n  %s\n  %s\n  %s\n</article>" % [heading, body, tags]
      
      
    end
    
    def make_page(title, raw_tags=title.downcase.gsub(/['\.\(\)]/,''))
      
      tags = raw_tags.split.join(' ')
      s = "#{title}\n\n\n+ " + tags
      write_md title, s
      write_xml title, build_xml(s)
      
      @entries.create title: title, tags: tags      
      
      return s
      
    end
    
    def read_md(title)
            
      filepath = File.join(File.absolute_path(@filepath), 'md', 
                           title.gsub(/ +/,'_') + '.md')      
      File.read(title.gsub(/ +/,'_') + '.md')
      
    end
    
    def write_md(title, content)
      
      filepath = File.join(File.absolute_path(@filepath), 'md', 
                           title.gsub(/ +/,'_') + '.md')
      FileUtils.mkdir_p File.dirname(filepath)      
      File.write filepath, content
      
    end
    
    def write_xml(title, content)
      
      filepath = File.join(File.absolute_path(@filepath), 'xml', 
                           title.gsub(/ +/,'_') + '.xml')
      FileUtils.mkdir_p File.dirname(filepath)      
      File.write filepath, content
      
    end    
    
  end

end
