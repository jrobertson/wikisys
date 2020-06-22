# Introducing the wiksys gem

    require 'wikisys'

    wiki = Wikisys::Wiki.new
    s = wiki.page 'Amazon Echo'
    #=> "Amazon Echo\n\n\n+ amazon echo" 

    wiki.page = "Bicycle\n\nI own a folding bike.\n\n+ bicycle"

In the above example a couple of new wiki entries are created and stored to Markdown files. The entry titles are stored in a file called *entries.json".

Note: When retrieving a page, if the title doesn't exist, then it's created.

## Resources

* wikisys https://rubygems.org/gems/wikisys

wikisys wiki gem
