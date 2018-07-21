require_relative 'codebreaker'

app = Rack::Builder.new do
  use Rack::ShowExceptions
  use Rack::Session::Cookie,
      key: 'codebreaker_session',
      path: '/',
      expire_after: 2_592_000,
      secret: '124c41+',
      old_secret: '124c41+'
  run Foo::CodebreakerApp
end

run app
