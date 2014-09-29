#!/usr/bin/ruby

require 'rubygems'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/file_storage'
require 'sinatra'
require "sinatra/reloader" if development?
require 'logger'
require 'multi_json'
require 'haml'
require 'sass'


set :bind, '0.0.0.0'
enable :sessions
enable :logging, :dump_errors, :raise_errors


CREDENTIAL_STORE_FILE = "#{$0}-oauth2.json"


# def logger; settings.logger end

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


    $log = Logger.new('log.txt','weekly')
    $log.level = Logger::DEBUG

    # log.debug "This will be ignored"
    # log.error "This will not be ignored" 
  
  client = Google::APIClient.new(
      :application_name => 'RIPHILMS Schedule Creator',
      :application_version => '2.0.0')
  #Dev
  client.authorization.client_id = '584929164737-tjb9o70hdqgbak7rf8ou0ieq1hqc4roq.apps.googleusercontent.com'
  client.authorization.client_secret = 'krNcqvYNlqOE9ML_svlRq2jT'
  #Production
  # client.authorization.client_id = '584929164737-aonbt0og06f981nfribu0aejcnjfluh6.apps.googleusercontent.com'
  # client.authorization.client_secret = 'FTDuIeH-E26hfRpN47IfVnnw'

  client.authorization.scope = 'https://www.googleapis.com/auth/calendar.readonly'
  calendar = client.discovered_api('calendar', 'v3')

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
  redirect user_credentials.authorization_uri(:approval_prompt => :auto).to_s, 303
end

get '/oauth2callback' do
  # Exchange token
  user_credentials.code = params[:code] if params[:code]
  user_credentials.fetch_access_token!
  redirect to('/')
end

helpers do
  # Create href to Gcal Event based on EventID
  def event_link(url,text)
    return "<a href='#{url}' target='_blank'>#{text}</a>"
  end
  # Insert entry into debug file
  def dbg(value)
    if value 
      File.write('debug.dbg',value.to_s+"\n", mode: 'a')
    end
  end
  # string to datetime
  def to_datetime(x)
    unless x == nil
      if x.length >10
        y = DateTime.strptime(x,"%Y-%m-%dT%H:%M:%S%z")
      else
        y = DateTime.strptime(x,"%Y-%m-%d")
      end
      return y
    end
    # dbg(x)
    # dbg(x.length)
  end
  def is_starttime(y)
    unless y == nil
      if y[:start][:dateTime]
        return to_datetime(y[:start][:dateTime]).to_s
      else
        $log.debug to_datetime(y[:start][:date]).to_s
        return to_datetime(y[:start][:date]).to_s
      end
    end
  end
  def is_endtime(y)
    unless y == nil
      if y[:end][:dateTime]
        return to_datetime(y[:end][:dateTime]).to_s
      else
        $log.debug to_datetime(y[:end][:date]).to_s
        return to_datetime(y[:end][:date]).to_s
      end
    end
  end
  def is_location(y)
      if y[:location]
        return y[:location]
      else
        $log.debug "No Location"
        return ""
      end
  end
  def from_datetime(time,row)
    if row[:location]
      y = to_datetime(time).strftime("%l:%M %p")
    else
      y=""
    end
    return y
    # dbg(x.length)
  end
end

get '/' do
  haml :index
end

post '/' do
  date = params[:date]
  redirect "/events/#{date}"
end

get '/events/:post_date' do |d|
  $log.debug "Get Calendars List"
  # Get list of calendars in account in JSON
  calendars = api_client.execute(:api_method => calendar_api.calendar_list.list,
                              :parameters => {'fields' => 'items/id'},
                              :authorization => user_credentials).data.to_json
  if calendars
    # add calendars to hash
    calendars_hash = MultiJson.load(calendars, :symbolize_keys => true)[:items]
    @calIds = []
    $log.debug "Add cal IDs to array"
    calendars_hash.each do |x|
      @calIds << x[:id]
    end
  else
    $log.error "No Calendars Found"
    ["No Calendars Found"]
  end
  # dbg(@calIds)

  # Set Date and Time Min
  if DateTime.strptime("#{d}","%Y-%m-%d").to_time.dst?
    timeZone = "-04:00"
  else
    timeZone = "-05:00"
  end
  dateIn = "#{d}"+"T00:00:00" + timeZone
  @timeMin = DateTime.strptime(dateIn)
  @timeMax = @timeMin.next
  $log.debug "Min Time: "+@timeMin.to_s
  $log.debug "Max Time: "+@timeMax.to_s


  # Get Events
  @events = []
  events_list = nil
   batch = Google::APIClient::BatchRequest.new do |result|
    events_list = result.data.to_json
    event_json = MultiJson.load(events_list, :symbolize_keys => true)
    # dbg(event_json)
    event_array = event_json[:items]
    event_array.each do |x|
    unless x == nil
      # dbg(event)
      # dbg("\n")
    @events << x
    end
  end
  end
  events_list_batch = nil
  @calIds.each do |x|
    events_list_batch = {:api_method => calendar_api.events.list,
                              :parameters =>  {'calendarId' => x, "timeMin" => @timeMin.strftime, "timeMax" => @timeMax.strftime, 'singleEvents' => "true",
                              "fields" => "items(description,htmlLink,location,originalStartTime,start,end,summary,updated)" },
                              :authorization => user_credentials}
    batch.add(events_list_batch)
  end

  api_client.execute(batch,:authorization => user_credentials) 
  # dbg(@events)
  # 
    $log.debug "sorting events"
    @sorted_events = @events.sort_by { |a| [is_location(a),is_starttime(a)] }
    $log.debug "Print Schedule"

haml :schedule




end 
