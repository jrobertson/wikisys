#!/usr/bin/env ruby

# file: wikisys.rb

require 'dxlite'
require 'dir-to-xml'
require 'mindwords'
require 'martile'
require 'hashcache'
require 'rxfreadwrite'


module FileFetch

  def fetch_filepath(filename)

    lib = File.dirname(__FILE__)    
    File.join(lib,'..','stylesheet',filename)

  end  
  
  def fetch_file(filename)

    filepath = fetch_filepath filename
    read filepath
  end  

  def read(s)
    RXFHelper.read(s).first
  end
end

module StringCase
  
  refine String do
    
    def capitalize2()
      self.sub(/^[a-z]/) {|x| x.upcase }
    end
    
  end
  
end

module Wikisys

  class Wiki
    include RXFReadWrite
    include FileFetch
    using ColouredText
    using StringCase

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


    def build_xml(filename)

      puts 'inside modify_buld' if @debug

      @title, @content, @tags = read_md(filename)

      # find the entry
      # modify the tags if necessary
      puts '@title: ' + @title.inspect if @debug
      puts '_ @content: ' + @content.inspect if @debug

      r = @entries.find_by_title @title
      puts 'r: ' + r.inspect if @debug

      if r.nil? then
        r = @entries.create title: @title, tags: @tags.join(' ')
      end


      filename = File.basename(filepath.sub(/\.md$/,'.xml'))
      xmlfile = File.join(@filepath, 'xml', filename)

      write_xml(xmlfile, make_xml(@title, @content, @tags))

      r.tags = @tags.join(' ') if r.tags != @tags

    end

    alias modify_build build_xml

    def new_build(filename)

      @title, @content, @tags = read_md(filename)
      @entries.create title: @title, tags: @tags.join(' ')

      puts 'md contents: ' + [@title, @content, @tags].inspect if @debug
      write_xml(@title, build_xml(@title, @content, @tags))

    end

    # used by wikisys::controler#import_mw
    #
    def new_md(filepath, s)

      write_file(filepath, md)
      #build_xml(filepath)

      #filename = File.basename(filepath.sub(/\.md$/,'.html'))
      #html_file = File.join(@filepath, 'html', filename)
      #write_html(html_file)

    end

    def read_file(file='index.html')
      @hc.read(file) { FileX.read(file) }
    end

    def to_css()
      fetch_file 'pg.css'
    end

    def write_html(filename)

      FileX.mkdir_p File.join(@filepath, 'html')

      xml = read_file File.join(@filepath, 'xml', filename)
      puts 'about to fetch_file' if @debug
      xsl = fetch_file 'pg.xsl'
      puts 'xsl: ' + xsl.inspect if @debug

      html_file = File.join(@filepath, 'html', filename.sub(/\.xml$/,'.html'))
      write_file(html_file, transform(xsl, xml))

    end

    private

    def read_md(filepath)

      #filepath = File.join(@filepath, 'md', filename)
      #puts 'filepath : ' + filepath.inspect if @debug
      return unless File.exists? filepath

      s = read_file(filepath).strip.gsub(/\r/,'')
      puts 's: ' + s.inspect if @debug

      # read the title
      title = s.lines.first.chomp.sub(/^# +/,'')

      # read the hashtags if there is any
      tagsline = s.lines.last[/^ *\+ +(.*)/,1]
      puts 'tagsline: ' + tagsline.inspect if @debug

      if tagsline then

        [title, s.lines[1..-2].join, tagsline.split]

      else

        [title, s.lines[1..-1].join, []]

      end

    end

    def make_xml(title, content, rawtags)

      puts 'content: ' + content.inspect if @debug
      s = content.gsub(/\[\[[^\]]+\]\]/) do |raw_link|

        r = @entries.find_by_title title

        e = Rexle::Element.new('a').add_text title
        e.attributes[:href] = title.gsub(/ +/, '_')

        if r then

          e.attributes[:title] = title.capitalize2

        else

          make_page(title.capitalize2)
          e.attributes[:class] = 'new'
          e.attributes[:title] = title.capitalize2 + ' (page does not exist)'

        end

        e.xml

      end


      heading = "<heading>%s</heading>" % title

      if rawtags.any? then

        list = tags.map {|tag| "    <tag>%s</tag>" % tag}
        tags = "<tags>\n%s\n  </tags>" % list.join("\n")

        body = "<body>\n    %s  </body>" % \
            Martile.new(s.lines[1..-2].join.strip).to_html

      else

        body = "<body>%s</body>" % Martile.new(s.lines[1..-1].join.strip).to_html
        tags = ''

      end

      "<article id='%s'>\n  %s\n  %s\n  %s\n</article>" % \
          [title.gsub(/ +/,'-'), heading, body, tags]


    end


    def transform(xsl, xml)

      doc   = Nokogiri::XML(xml)
      xslt  = Nokogiri::XSLT(xsl)

      xslt.transform(doc)

    end

    def write_xml(s, content)

      filename = s =~ /\.xml$/ ? s :  s.gsub(/ +/,'_') + '.xml'
      filepath = File.join(File.absolute_path(@filepath), 'xml', filename)
      FileX.mkdir_p File.dirname(filepath)
      #FileX.write filepath, content
      write_file filepath, content

    end

    def write_file(filepath, content)

      puts 'writing file: ' + filepath.inspect if @debug
      FileX.write filepath, content
      @hc.write(filepath) { content }
    end

    def make_page(title, raw_tags=title.downcase.gsub(/['\.\(\)]/,''))

      tags = raw_tags.split.join(' ')
      s = "#{title}\n\n\n+ " + tags
      write_md title, s
      write_xml title, build_xml(s)

      @entries.create title: title, tags: tags
      @title, @content, @tags = title, '', tags

      return s

    end

    def read_md_file(filename)

      filepath = File.join(@filepath, 'md', filename)
      FileX.read(filepath)

    end

    def write_md_to_be_deleted(title, content)

      puts 'inside write_md' if @debug
      filename = s =~ /\.md$/ ? s :  s.gsub(/ +/,'_') + '.md'
      filepath = File.join(File.absolute_path(@filepath), 'md', filename)
      FileX.mkdir_p File.dirname(filepath)
      FileX.write filepath, content

    end


  end

  class Pages

    attr_accessor :mw, :entries

    def initialize(filepath='.', debug: false)

      @filepath, @debug = filepath, debug

      entries_file = File.join(@filepath, 'entries.xml')

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

      @pg = Wiki.new @filepath, entries: @entries, debug: @debug

      #scan_md_files()

    end

    def import_mw(obj=File.join(@filepath, 'mindwords.txt'))

      s, _ = RXFReader.read(obj)

      @mw = MindWords.new(s)
      FileX.write 'outline.txt', @mw.to_outline

      FileX.mkdir_p 'md'
      FileX.mkdir_p 'html'

      @mw.to_words.each do |title, attributes|

        breadcrumb, hashtags = attributes.values

        s = "# %s\n\n\n" % title.capitalize2
        s += '+ ' + hashtags if hashtags.strip.length > 0

        file = File.join(@filepath, 'md', title.capitalize2.gsub(/ +/,'-') \
                         + '.md')

        if not File.exists?(file) then

          @pg.new_md(file, s)

        end

      end

      #gen_html_files()
      gen_sidenav()
    end

    # creates a new page from an existing Markdown file
    #
    def new_pg(filename)

      @pg.new_build(filename)
      @entries.save

      update_mw(@pg.title, @pg.tags)
      @mw.save if @mw.lines.any?

      build_html(filename)

    end

    # refreshes an existing page from an existing Markdown file
    #
    def update_pg(filename)

      @pg.modify_build(filename)
      @entries.save

      update_mw(@pg.title, @pg.tags)
      @mw.save if @mw.lines.any?

      build_html(filename)

    end

    private

    def build_html(filename)

      xml_file = filename.sub(/\.md$/,'.xml')
      filepath = File.join(@filepath, 'xml', xml_file)
      s = @pg.read_file filepath
      title = Rexle.new(s).root.text('heading')
      puts 'about to search title: ' + title.inspect if @debug
      found = @mw.search(title)

      if found then

        links = found.breadcrumb.map do |x|
          [x, x.gsub(/ +/,'-') + '.html']
        end

        @pg.create_breadcrumb(filepath, links)

      end

      @pg.write_html xml_file

    end

    # Check if any of the md files have been modified or newly created
    #
    def scan_md_files()

      filepath = File.join(@filepath, 'md')
      puts 'about to scan ' + filepath.inspect if @debug
      dir = DirToXML.new(filepath, index: 'dir.json', debug: @debug)
      h = dir.activity
      puts 'h: ' + h.inspect if @debug

      return if (h[:new] + h[:modified]).empty?

      h[:new].each {|filename| new_pg(filename) }
      h[:modified].each {|filename| update_pg(filename) }

      @mw.save if @mw.lines.any?
      outline_filepath = File.join(@filepath, 'myoutline.txt')

      FileX.write outline_filepath, @mw.to_outline

      (h[:new] + h[:modified]).each do |filename|

        build_html filename

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
      @hc.read(file) { FileX.read(file) }
    end

  end

  class Controller
    using StringCase

    def initialize(filepath: '.')
      @filepath = filepath

      @pages = Pages.new filepath

    end

    def import_mw(obj)

      s, _ = RXFReader.read(obj)

      @mw = MindWords.new(s)
      FileX.write 'outline.txt', @mw.to_outline

      FileX.mkdir_p 'md'
      FileX.mkdir_p 'html'

      @mw.to_words.each do |title, attributes|

        breadcrumb, hashtags = attributes.values

        s = "# %s\n\n\n" % title.capitalize2
        s += '+ ' + hashtags if hashtags.strip.length > 0

        file = File.join(@filepath, 'md', title.capitalize2.gsub(/ +/,'-') \
                         + '.md')

        if not File.exists?(file) then

          pg.new_md(file, s)

        end

      end

      #gen_html_files()
      gen_sidenav()
    end
  end
end
