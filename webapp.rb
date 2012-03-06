require 'bundler'
Bundler.setup
Bundler.require(:default, :webapp)

require './client'
require 'mustache/sinatra'

class WebApp < Sinatra::Base
  register Sinatra::Reloader
  register Mustache::Sinatra
  require './views/layout'
  
  set :mustache, {
    :namespace => App,
    :templates => "./templates",
    :views => "./views"
  }
  
  get '/' do
#    redirect '/login' if !logged_in?
    
      
    mustache :index
  end
  
  get '/' do
    session[:client] = WebClient.new(ENV["CSE_HOST"], ENV["CSE_USERNAME"], ENV["CSE_PASSWORD"])
    
    
  end
  
end
