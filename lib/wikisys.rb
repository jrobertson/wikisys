#!/usr/bin/env ruby

# file: wikisys.rb

require 'dxlite'
require 'dir-to-xml'
require 'mindwords'
require 'martile'

module FileFetch

  def fetch_filepath(filename)

    #lib = File.dirname(__FILE__)    
    #File.join(lib,'..','stylesheet',filename)
    lib = 'http://a0.jamesrobertson.me.uk/rorb/r/ruby/wikisys/stylesheet'
    File.join(lib, filename)
  end  
  
  def fetch_file(filename)

    filepath = fetch_filepath filename
    read filepath
  end  

  def read(s)
    RXFHelper.read(s).first
  end
end

module Wikisys

  class Wiki    
    include FileFetch
    using ColouredText
    
    attr_accessor :title, :content, :tags
    attr_reader :to_xml

    def initialize(filepath='.', entries: 'entries.json', debug: false)

      @filepath = filepath
      @page = ''
      @debug = debug
      
      @hc = HashCache.new(size:30)

      @entries = if entries.is_a? DxLite then
      
        entries
        
      elsif File.exists?(entries) then
      
        DxLite.new(entries)

      else

        DxLite.new('entries/entry(title, tags)')

      end
    
    end
    
    def create_breadcrumb(filepath, links)
  
      doc = Rexle.new(read_file(filepath))
      heading = doc.root.element('heading')
      
      menu = Rexle.new(HtmlCom::Menu.new(:breadcrumb, links).to_html)
      
      heading.insert_before menu.root
      write_file filepath, doc.root.xml
          
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
    
    def read_file(file='index.html')
      @hc.read(file) { File.read(file) }
    end
    
    def to_css()
      fetch_file 'pg.css'
    end
    
    def write_html(filename)

      FileUtils.mkdir_p File.join(@filepath, 'html')
      
      xml = read_file File.join(@filepath, 'xml', filename)
      puts 'about to fetch_file' if @debug
      xsl = fetch_file 'pg.xsl'
      puts 'xsl: ' + xsl.inspect if @debug
      
      html_file = File.join(@filepath, 'html', filename.sub(/\.xml$/,'.html'))
      write_file(html_file, transform(xsl, xml))

    end
    
    private
    
    def read_md(filename)
      
      filepath = File.join(@filepath, 'md', filename)
      return unless File.exists? filepath
      
      s = read_file(filepath).strip
      
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
            
      "<article id='%s'>\n  %s\n  %s\n  %s\n</article>" % \
          [title.downcase.gsub(/ +/,'-'), heading, body, tags]
      
      
    end
    
    
    def transform(xsl, xml)

      doc   = Nokogiri::XML(xml)
      xslt  = Nokogiri::XSLT(xsl)

      xslt.transform(doc)      
      
    end    
    
    def write_xml(title, content)
      
      filepath = File.join(File.absolute_path(@filepath), 'xml', 
                           title.downcase.gsub(/ +/,'_') + '.xml')
      FileUtils.mkdir_p File.dirname(filepath)      
      #File.write filepath, content
      write_file filepath, content
      
    end          
    
    def write_file(filepath, content)
      
      puts 'writing file: ' + filepath.inspect if @debug
      File.write filepath, content
      @hc.write(filepath) { content }      
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
      
      return if (h[:new] + h[:modified]).empty?
      
      pg = Wiki.new @filepath, entries: @entries, debug: @debug
                    
      
      h[:new].each do |filename|

        pg.new_build(filename)
        update_mw(pg.title, pg.tags)
        
      end
      
      h[:modified].each do |filename|
        
        pg.modify_build(filename)
        update_mw(pg.title, pg.tags)
                
      end

      @mw.save if @mw.lines.any?      
      outline_filepath = File.join(@filepath, 'myoutline.txt')
      
      File.write outline_filepath, @mw.to_outline
      
      (h[:new] + h[:modified]).each do |filename|
        
        xml_file = filename.sub(/\.md$/,'.xml')
        filepath = File.join(@filepath, 'xml', xml_file)
        s = pg.read_file filepath
        title = Rexle.new(s).root.text('heading')
        puts 'about to search title: ' + title.inspect if @debug
        found = @mw.search(title)
        
        if found then
        
          links = found.breadcrumb.map do |x| 
            [x, x.downcase.gsub(/ +/,'-') + '.html']
          end
                    
          pg.create_breadcrumb(filepath, links)
          
        end
        
        pg.write_html xml_file
        
      end
      
      @entries.save

      
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
    
    def view_file(file='index.html')
      @hc.read(file) { File.read(file) }
    end

  end
end
