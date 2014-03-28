require 'rubygems'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/file_storage'
require 'sinatra'
require "sinatra/reloader" if development?
require 'logger'
require 'multi_json'
set :bind, '0.0.0.0'
enable :sessions

CREDENTIAL_STORE_FILE = "#{$0}-oauth2.json"

def logger; settings.logger end

def api_client; settings.api_client; end

def calendar_api; settings.calendar; end

def user_credentials
  # Build a per-request oauth credential based on token stored in session
  # which allows us to use a shared API client.
  @authorization ||= (
    auth = api_client.authorization.dup
    auth.redirect_uri = to('/oauth2callback')
    auth.update_token!(session)
    auth
  )
end

configure do
  log_file = File.open('calendar.log', 'a+')
  log_file.sync = true
  logger = Logger.new(log_file)
  logger.level = Logger::DEBUG

  client = Google::APIClient.new(
      :application_name => 'Ruby Calendar sample',
      :application_version => '1.0.0')
  client.authorization.client_id = '584929164737-2ehd7bvh7iv9f3plcdfcohpb9kq5m1ri.apps.googleusercontent.com'
  client.authorization.client_secret = 'W_eRqavVE-fvgAGYzcu9yUtY'
  client.authorization.scope = 'https://www.googleapis.com/auth/calendar'
  calendar = client.discovered_api('calendar', 'v3')

  set :logger, logger
  set :api_client, client
  set :calendar, calendar
end

before do
  # Ensure user has authorized the app
  unless user_credentials.access_token || request.path_info =~ /\A\/oauth2/
    redirect to('/oauth2authorize')
  end
end

after do
  # Serialize the access/refresh token to the session and credential store.
  session[:access_token] = user_credentials.access_token
  session[:refresh_token] = user_credentials.refresh_token
  session[:expires_in] = user_credentials.expires_in
  session[:issued_at] = user_credentials.issued_at

  file_storage = Google::APIClient::FileStorage.new(CREDENTIAL_STORE_FILE)
  file_storage.write_credentials(user_credentials)
end

get '/oauth2authorize' do
  # Request authorization
  redirect user_credentials.authorization_uri.to_s, 303
end

get '/oauth2callback' do
  # Exchange token
  user_credentials.code = params[:code] if params[:code]
  user_credentials.fetch_access_token!
  redirect to('/')
end


  # Fetch list of events on the user's default calandar
  calendars = api_client.execute(:api_method => calendar_api.calendar_list.list,
                              # :parameters => {'calendarId' => 'primary'},
                              :authorization => user_credentials)
  # calendar = MultiJson.load(calendars)
  cal = calendars.to_s

  erb cal
 
  [calendars.status, {'Content-Type' => 'application/json'}, calendars.data.to_json]


