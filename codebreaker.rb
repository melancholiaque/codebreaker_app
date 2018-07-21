require_relative 'foo'

def not_ok(msg)
  { status: :fail, msg: msg }
end

def ok(content)
  { status: :ok, content: content }
end

Foo.define do
  get '/', type: :json do
    'hello'
  end

  get '/register/:name/:pass', type: :json do |name, pass|
    # name, pass = body['name'], body['pass']
    if !name || !pass
      not_ok 'provide name and password'
    elsif (name = manager.register(name, pass))
      session[:name] = name
      ok 'successfully registered'
    else
      not_ok 'such user already exists'
    end
  end

  get '/verify/:name/:pass', type: :json do |name, pass|
    if (name = manager.verify(name, pass))
      session[:name] = name
      ok 'logged in'
    else
      not_ok 'wrong creditnails'
    end
  end
end
