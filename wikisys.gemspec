Gem::Specification.new do |s|
  s.name = 'wikisys'
  s.version = '0.4.1'
  s.summary = "A poor man's wiki."
  s.authors = ['James Robertson']
  s.files = Dir['lib/wikisys.rb','stylesheet/*.xsl','stylesheet/*.css']
  s.add_runtime_dependency('dir-to-xml', '~> 1.0', '>=1.0.4')
  s.add_runtime_dependency('mindwords', '~> 0.5', '>=0.5.4')
  s.add_runtime_dependency('martile', '~> 1.4', '>=1.4.6')
  s.add_runtime_dependency('hashcache', '~> 0.2', '>=0.2.10')
  s.signing_key = '../privatekeys/wikisys.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/wikisys'
end
