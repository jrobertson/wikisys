Gem::Specification.new do |s|
  s.name = 'wikisys'
  s.version = '0.5.1'
  s.summary = "A poor man's wiki (currently unmaintained)."
  s.authors = ['James Robertson']
  s.files = Dir['lib/wikisys.rb','stylesheet/*.xsl','stylesheet/*.css']
  s.add_runtime_dependency('dir-to-xml', '~> 1.2', '>=1.2.2')
  s.add_runtime_dependency('mindwords', '~> 0.8', '>=0.8.1')
  s.add_runtime_dependency('martile', '~> 1.6', '>=1.6.2')
  s.add_runtime_dependency('hashcache', '~> 0.2', '>=0.2.10')
  s.signing_key = '../privatekeys/wikisys.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/wikisys'
end
