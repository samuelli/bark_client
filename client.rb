require 'bundler'
Bundler.setup
Bundler.require(:default)

class Reader
  def self.scan
    # TODO: This is for Mac, do a `uanme` compare to select the device
    SerialPort.open('/dev/tty.usbserial-A6009nts', 115200) do |s|
      while true
        line = s.readline.match(/UID: (.*)$/)
        if line && line[1]
          return line[1]
        end
      end
    end
  end
end

class Event
  attr_reader :name, :id
  def initialize(options = {})
    @name = options[:name]
    @client = options[:client]
    @id = options[:id]
    @conn = @client.conn
  end

  def check_in_with_rfid(value)
    @conn.post('/api/v1/checkin', {:rfid => value, :event_id => id})
  end
  
  def check_in_with_student_id(value)
    @conn.post('/api/v1/checkin', {:student_id => value, :event_id => id})
  end
  
  def to_json(args)
    {:name => name, :id => id}.to_json(args)
  end

end

module FaradayMiddleware
  class Cookies < Faraday::Middleware

    def initialize(app, options = {})
      super(app)
      @cookie = nil
    end
    
    def call(env)
      env[:request_headers]['Cookie'] = @cookie if @cookie
      resp = @app.call(env)
      if env[:response_headers]['set-cookie']
        @cookie = env[:response_headers]['set-cookie'].split('; ')[0]
      end
      if env[:status] == 401
        raise "Unauthorized"
      end
      resp
    end
  end
end

class WebClient
  class InvalidLogin < StandardError; end
  attr_reader :conn
  
  def initialize(url, username, password)
    @cookie = nil
    @conn = Faraday.new(:url => url) do |builder|
      builder.use FaradayMiddleware::ParseJson, :content_type => /\bjson$/
      builder.use FaradayMiddleware::Cookies
      builder.request :url_encoded
      builder.adapter :net_http
    end
    
    response = @conn.post('/auth/login', {:student_id => username, :password => password})
    if response.body["status"] == "LOGGED_IN"
      # Logged in!
    else
      raise InvalidLogin
    end
  end
  
  def events
    @conn.get('/api/v1/events').body["events"].map do |event|
      Event.new(:client => self, :name => event["name"], :id => event["id"])
    end
  end
  
  def register_user(options = {})
    @conn.post('/api/v1/register', options)
  end
end
