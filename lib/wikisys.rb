#!/usr/bin/env ruby

# file: wikisys.rb

require 'dxlite'
require 'dir-to-xml'
require 'mindwords'
require 'martile'

module Wikisys

  class Wiki
    
    attr_accessor :title, :content, :tags
    attr_reader :to_xml

    def initialize(filepath='.', entries: 'entries.json', debug: false)

      @filepath = filepath
      @page = ''
      @debug = debug

      @entries = if entries.is_a? DxLite then
      
        entries
        
      elsif File.exists?(entries) then
      
        DxLite.new(entries)

      else

        DxLite.new('entries/entry(title, tags)')

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
      title, content, tags = read_md()
      @to_xml = build_xml title, content, tags
      write_xml title, @to_xml

      
      @entries.save
      @page = raw_content
      
    end    
    
    def modify_build(filename)
      
      @title, @content, @tags = read_md(filename)
      
      # find the entry
      # modify the tags if necessary
      
      r = @entries.find_by_title @title
      puts 'r: ' + r.inspect if @debug
      return unless r
      
      write_xml(@title, build_xml(@title, @content, @tags))
      
      r.tags = @tags.join(' ') if r.tags != @tags
      
    end        
    
    def new_build(filename)
      
      @title, @content, @tags = read_md(filename)      
      @entries.create title: @title, tags: @tags.join(' ')

      puts 'md contents: ' + [@title, @content, @tags].inspect if @debug
      write_xml(@title, build_xml(@title, @content, @tags))      
      
    end
    
    private
    
    def read_md(filename)
      
      filepath = File.join(@filepath, 'md', filename)
      return unless File.exists? filepath
      
      s = File.read(filepath).strip
      
      # read the title
      title = s.lines.first.chomp.sub(/^# +/,'')
      
      # read the hashtags if there is any
      tagsline = s.lines.last[/^ *\+ +(.*)/,1]
      
      if tagsline then
        
        [title, s.lines[1..-2].join, tagsline.split]
      
      else
        
        [title, s.lines[1..--1].join, []]
        
      end
      
    end                  

    
    def build_xml(title, content, tags)
      
      puts 'content: ' + content.inspect if @debug
      s = content.gsub(/\[\[[^\]]+\]\]/) do |raw_link|
        
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
      
      
      heading = "<heading>%s</heading>" % title
      
      if tags.any? then
      
        list = tags.map {|tag| "    <tag>%s</tag>" % tag}
        tags = "<tags>\n%s\n  </tags>" % list.join("\n")
        
        body = "<body>\n    %s  </body>" % \
            Martile.new(s.lines[1..-2].join.strip).to_html
        
      else
        
        body = "<body>%s</body>" % Martile.new(s.lines[1..-1].join.strip).to_html

      end
            
      "<article>\n  %s\n  %s\n  %s\n</article>" % [heading, body, tags]
      
      
    end
    
    def write_xml(title, content)
      
      filepath = File.join(File.absolute_path(@filepath), 'xml', 
                           title.gsub(/ +/,'_') + '.xml')
      FileUtils.mkdir_p File.dirname(filepath)      
      File.write filepath, content
      
    end          
    
    def make_page(title, raw_tags=title.downcase.gsub(/['\.\(\)]/,''))
      
      tags = raw_tags.split.join(' ')
      s = "#{title}\n\n\n+ " + tags
      write_md title, s
      write_xml title, build_xml(s)
      
      @entries.create title: title, tags: tags      
      
      return s
      
    end          
    
    def read_md_file(filename)
      
      filepath = File.join(@filepath, 'md', filename)
      File.read(filepath)
      
    end
    
    def write_md(title, content)
      
      filepath = File.join(File.absolute_path(@filepath), 'md', 
                           title.gsub(/ +/,'_') + '.md')
      FileUtils.mkdir_p File.dirname(filepath)      
      File.write filepath, content
      
    end      
    
  end
  
  class Pages
    
    attr_accessor :mw, :entries

    def initialize(filepath='.', debug: false)
      
      @filepath, @debug = filepath, debug
      
      entries_file = File.join(@filepath, 'entries.txt')
      
      if File.exists?(entries_file) then
        @entries = DxLite.new(entries_file)
      else
        @entries = DxLite.new('entries/entry(title, tags)')
        @entries.save entries_file
      end

      # check for the mindwords raw document file
      mindwords_file = File.join(@filepath, 'mindwords.txt')
      
      if File.exists?(mindwords_file) then 
        @mw = MindWords.new(mindwords_file)
      else
        @mw = MindWords.new
        @mw.filepath = mindwords_file
      end
      
      scan_md_files()
      
    end
    
    private        

    
    # Check if any of the md files have been modified or newly created
    #
    def scan_md_files()
      
      filepath = File.join(@filepath, 'md')
      puts 'about to scan ' + filepath.inspect if @debug
      dir = DirToXML.new(filepath, index: 'dir.json', debug: @debug)
      h = dir.activity
      puts 'h: ' + h.inspect if @debug
      
      pg = Wiki.new @filepath, entries: @entries
                    
      
      h[:new].each do |filename|

        pg.new_build(filename)
        update_mw(pg.title, pg.tags)
        
      end
      
      h[:modified].each do |filename|
        
        pg.modify_build(filename)
        update_mw(pg.title, pg.tags)
                
      end
      
      @entries.save
      @mw.save if @mw.lines.any?
      
    end # /scan_md_files       
    
    def update_mw(title, line_tags)
      
      # read the file

      tags = line_tags.reject {|x| x =~ /#{title.strip}/i}
      puts 'tags: '  + tags.inspect if @debug
      puts 'title: ' + title.inspect if @debug
      
      return if tags.empty?
      
      line = title + ' ' + tags.map {|x| "#" + x }.join(' ') + "\n"
      puts 'line: ' + line.inspect if @debug
      
      # does the tagsline contain the topic hashtag?
      
      #if tagsline =~ /#/ # not yet implemented
        

                            
      # check if the title already exists
      found = @mw.lines.grep(/^#{title} +(?=#)/i)
      
      if found.any? then
        
        found_tags = found.first.scan(/(?<=#)\w+/)
        
        if @debug then
          
          puts 'tags: ' + tags.inspect
          puts 'found_tags: ' + found_tags.inspect
        
        end

        new_tags = tags - found_tags   
        
        # add the new tags to the mindwords line
        
        hashtags = (found_tags + new_tags).map {|x| '#' + x }.join(' ')

        i = @mw.lines.index(found.first)
        @mw.lines[i] = line
        
      else
        
        @mw.lines <<  line
        
      end                            
      
    end
  end
end
