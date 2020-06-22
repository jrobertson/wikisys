Gem::Specification.new do |s|
  s.name = 'wikisys'
  s.version = '0.1.1'
  s.summary = "A poor man's wiki."
  s.authors = ['James Robertson']
  s.files = Dir['lib/wikisys.rb']
  s.add_runtime_dependency('dxlite', '~> 0.2', '>=0.2.1')
  s.signing_key = '../privatekeys/wikisys.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/wikisys'
end
