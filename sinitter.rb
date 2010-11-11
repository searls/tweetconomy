#!/usr/bin/env ruby
require 'rubygems'
require 'sinatra'
require 'twitter_oauth'
require 'yaml'

configure do
  set :sessions, true
  @@config = YAML.load_file("config.yml")
end

before do
  next if request.path_info =~ /ping$/
  @user = session[:user]
  @client = TwitterOAuth::Client.new(
    :consumer_key => ENV['CONSUMER_KEY'] || @@config['consumer_key'],
    :consumer_secret => ENV['CONSUMER_SECRET'] || @@config['consumer_secret'],
    :token => session[:access_token],
    :secret => session[:secret_token]
  )
  @rate_limit_status = @client.rate_limit_status
end

get '/' do
  redirect '/calculate' if @user
  erb :signin
end

get '/calculate' do
  @tweet_count = @client.user.size
  @potential_chars = 140 * @client.user.size
  sizes = @client.user.map { |s| s['text'].size }
  @shortest_tweet = sizes.min
  @longest_tweet = sizes.max
  @chars_used = sizes.reduce(:+)
  @percent_used = sprintf("%0.2f\%", (@chars_used / (@potential_chars*1.0))*100)
  erb :calculate
end

post '/update' do
  @client.update(params[:update])
  redirect '/calculate'
end

# store the request tokens and send to Twitter
get '/connect' do
  request_token = @client.request_token(
    :oauth_callback => ENV['CALLBACK_URL'] || @@config['callback_url']
  )
  session[:request_token] = request_token.token
  session[:request_token_secret] = request_token.secret
  redirect request_token.authorize_url.gsub('authorize', 'authenticate') 
end

# auth URL is called by twitter after the user has accepted the application
# this is configured on the Twitter application settings page
get '/auth' do
  # Exchange the request token for an access token.
  
  begin
    @access_token = @client.authorize(
      session[:request_token],
      session[:request_token_secret],
      :oauth_verifier => params[:oauth_verifier]
    )
  rescue OAuth::Unauthorized
  end
  
  if @client.authorized?
      # Storing the access tokens so we don't have to go back to Twitter again
      # in this session.  In a larger app you would probably persist these details somewhere.
      session[:access_token] = @access_token.token
      session[:secret_token] = @access_token.secret
      session[:user] = true
      redirect '/calculate'
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

helpers do 
  def partial(name, options={})
    erb("_#{name.to_s}".to_sym, options.merge(:layout => false))
  end
end