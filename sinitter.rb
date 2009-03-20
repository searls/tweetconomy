#!/usr/bin/env ruby
require 'rubygems'
require 'sinatra'
require 'twitter_oauth'

configure do
  set :sessions, true
  @@config = YAML.load_file("config.yml") rescue nil || {}
  TwitterOAuth::Client::CLIENT_KEY = @@config['consumer_key']
  TwitterOAuth::Client::CLIENT_SECRET = @@config['consumer_secret']
end

before do
  @user = session[:user]
  @client = TwitterOAuth::Client.new(:token => session[:access_token], :secret => session[:secret_token])
end

get '/' do
  erb :home
end

post '/update' do
  @client.update(params[:update])
  redirect '/'
end

# store the request tokens and send to Twitter
get '/connect' do
  request_token = @client.request_token
  session[:request_token] = request_token.token
  session[:request_token_secret] = request_token.secret
  redirect request_token.authorize_url  
end

# auth URL is called by twitter after the user has accepted the application
# this is configured on the Twitter application settings page
get '/auth' do
  # Exchange the request token for an access token.
  @access_token = @client.login(
    session[:request_token],
    session[:request_token_secret]
  )
  
  if @client.authorized?
      # Storing the access tokens so we don't have to go back to Twitter again
      # in this session.  In a larger app you would probably persist these details somewhere.
      session[:access_token] = @access_token.token
      session[:secret_token] = @access_token.secret
      session[:user] = true
      redirect '/'
    else
      redirect '/'
  end
end

get '/disconnect' do
  session[:user] = nil
  session[:request_token] = nil
  session[:request_token_secret] = nil
  session[:access_token] = nil
  session[:secret_token] = nil
  redirect '/'
end
