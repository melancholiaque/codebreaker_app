require 'json'
require 'gdbm'
require 'digest'

# inspired by sinatra
module Foo
  # provides execution context for http methods, regex sequance traversial
  # and helper methods
  class Holder
    attr_reader :method, :path, :params, :body, :session

    def initialize(*params)
      names = %i[method path params body session]
      names.zip(params).map { |n, v| define_singleton_method(n) { v } }
    end

    def self.from_request(req)
      body = JSON.parse(req.body.read) rescue req.body.read
      params = req.params
      session = req.session
      method = req.request_method
      path = req.path
      new(method, path, params, body, session)
    end

    def attach(**kwargs)
      kwargs.each_pair do |k, v|
        define_singleton_method(k) { v }
      end
    end

    def login_required
      raise Forbiden if session[:name].nil?
    end

    def callback_from(paths)
      paths[method].each do |re, hd, cb, conv|
        return [hd, closure(preprocess($~), &cb), conv] if re =~ path
      end
      nil
    end

    def preprocess(path_params_match)
      path_params_match.captures.map { |e| /[0-9]+/ =~ e ? e.to_i : e }
    end

    def closure(path_params, &block)
      -> { instance_exec(*path_params, &block) }
    end
  end

  class Forbiden < RuntimeError
  end

  # handles authorization
  class AuthManager
    def initialize(name = nil)
      @store = name ? GDBM.new("#{name}.db") : {}
      @key = [Time.now, rand].join
    end

    def register(name, pass)
      return nil if @store[name]
      @store[name] = Digest::MD5.hexdigest(pass)
      name
    end

    def verify(name, pass)
      @store[name] == Digest::MD5.hexdigest(pass) ? name : nil
    end
  end

  # defines http methods and regex sequence
  class Router
    CONVERTERS = {
      json: [:to_json, 'application/json'],
      text: [:to_s, 'text/plain'],
      html: [:to_s, 'text/html']
    }.freeze

    def initialize
      @paths = Hash.new { |h, v| h[v] = [] }
      @auth_manager = AuthManager.new('test')
    end

    def call(env)
      hold = Holder.from_request(Rack::Request.new(env))
      hold.attach(manager: @auth_manager)
      hd, cb, conv = hold.callback_from(@paths)
      return the_404 unless cb
      [200, hd, [cb.call.send(conv)]]
    rescue Forbiden
      [403, hd, ['Forbiden']]
    end

    def make_regex(path)
      Regexp.new "^#{path.gsub(/:([\w\d]+)/, '([\w\d]+)')}/?$"
    end

    %i[get post].each do |method|
      define_method(method) do |path, **kwargs, &block|
        conv, cont = CONVERTERS[kwargs[:type] || :text]
        @paths['GET'] << [
          make_regex(path), { 'Content-Type' => cont }, block, conv
        ]
      end
    end

    def the_404
      [404, { 'Content-Type' => 'text/plain' }, ['whoopsie']]
    end
  end

  def self.define(&block)
    router = Router.new.tap do |s|
      s.instance_eval(&block)
    end
    const_set("#{caller(1..1).first[/[\w\d]+?(?=\.rb)/].capitalize}App", router)
  end
end
