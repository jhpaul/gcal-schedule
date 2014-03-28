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
  client.authorization.scope = 'https://www.googleapis.com/auth/calendar.readonly'
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
# def ids(x)
#   x.each do |id|
#     puts id
#   end
# end
get '/' do
  # Fetch list of calendar ids
  calendars = api_client.execute(:api_method => calendar_api.calendar_list.list,
                              :parameters => {'fields' => 'items/id'},
                              :authorization => user_credentials)
  calendars_json = calendars.data.to_json
  calendars_hash = MultiJson.load(calendars_json, :symbolize_keys => true)
  calendar_id_list = calendars_hash[:items]
  File.write('cal-ids-hash.dbg', calendar_id_list)
  cal_id_count = calendar_id_list.length
  calendar_ids = []
  i=0
  # create array of ids
  while i < cal_id_count
    calendar_id_list[i].each do |key, id|
      calendar_ids << id
    end
    i = i+1
  end
  File.write('cal-ids.dbg', calendar_ids)
  # [all]
  # erb <hr>
  # erb ids(calendars)
  # for each cal id, pull event id
  timeMin = "2014-03-31T04:00:00Z"
  timeMax = "2014-04-01T04:00:00Z"
  event_ids = []
  events = []
  calendar_ids.each do |x|
    # events << "begin cal #{x}"
    events_list = api_client.execute(:api_method => calendar_api.events.list,
                              :parameters => {'calendarId' => x, 'singleEvents' => "true", "timeMin" => timeMin, "timeMax" => timeMax,  "fields" => "items/id" },
                              :authorization => user_credentials)
    events_list_json = events_list.data.to_json
    events_list_hash = MultiJson.load(events_list_json, :symbolize_keys => true)
    event_id = events_list_hash[:items]
   
    event_id_count = event_id.length
    n = 0
    while n < event_id_count
      event_id[n].each do |key, id|
        event_ids << id
      end
      n = n+1
    end
    
    for y in event_ids do
      event = api_client.execute(:api_method => calendar_api.events.get,
                                :parameters => {'calendarId' => x, 'eventId' => y, "fields" => "description,htmlLink,location,originalStartTime,start,end,summary,updated" },
                                :authorization => user_credentials)
      event_data = event.data.to_json
      event_json = MultiJson.load(event_data, :symbolize_keys => true)
      unless event_json[:error]
        events << event_json
      end

      
    end
  end
  File.write('event_ids.dbg', event_ids)
  File.write('events.dbg', events)
  [events.to_json]
end