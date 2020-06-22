Gem::Specification.new do |s|
  s.name = 'wikisys'
  s.version = '0.2.0'
  s.summary = "A poor man's wiki."
  s.authors = ['James Robertson']
  s.files = Dir['lib/wikisys.rb']
  s.add_runtime_dependency('dxlite', '~> 0.2', '>=0.2.2')
  s.add_runtime_dependency('martile', '~> 1.4', '>=1.4.3')
  s.signing_key = '../privatekeys/wikisys.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/wikisys'
end
