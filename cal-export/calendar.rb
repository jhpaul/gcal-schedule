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
require 'pdfkit'

set :bind, '0.0.0.0'
enable :sessions
enable :logging, :dump_errors, :raise_errors

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
  #Dev
  # client.authorization.client_id = '584929164737-tjb9o70hdqgbak7rf8ou0ieq1hqc4roq.apps.googleusercontent.com'
  # client.authorization.client_secret = 'krNcqvYNlqOE9ML_svlRq2jT'
  #Production
  client.authorization.client_id = '584929164737-aonbt0og06f981nfribu0aejcnjfluh6.apps.googleusercontent.com'
  client.authorization.client_secret = 'FTDuIeH-E26hfRpN47IfVnnw'

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

helpers do
  def event_link(url,text)
   return "<a href='#{url}' target='_blank'>#{text}</a>"
  end
  def to_datetime(x)
    unless x == nil
      if x.length >10
        y = DateTime.strptime(x,"%Y-%m-%dT%H:%M:%S%z")
      else
        y = DateTime.strptime(x,"%Y-%m-%d")
      end
      return y
    end
    dbg(x)
    # dbg(x.length)
  end
  def from_datetime(z)
    y = "NODATE"
    if z.class == DateTime
      y = z.strftime("%l:%M %p")
    end

    dbg(y)
    dbg(y.class)
    return y
    # dbg(x.length)
  end
  def dbg(value)
    if value 
      File.write('debug.dbg',value.to_s+"\n", mode: 'a')
    end
  end

end
get '/' do
  # sass :style
  haml :index
end
post '/' do
  date = params[:date]
  redirect "/events/#{date}"
end


# Build Schedule based on 
get '/s/:post_date' do
  file = File.read('events.dbg')
  data = [{:htmlLink=>"https://www.google.com/calendar/event?eid=cDlhbnQwNGNrdHM3NXI5M2s1azJiMmlhaG9fMjAxNDAzMzFUMjIwMDAwWiBocTVwdHRnbDVhMTdiNGg0b3Q3OTRnY2NtNEBn", :updated=>"2014-03-26T20:39:31.605Z", :summary=>"Sullivan", :location=>"116", :start=>{:dateTime=>"2014-03-31T18:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T18:30:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T18:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=YzMxN3Z0Z2Fkc3B1cjBicGt0ZmZudDhibGNfMjAxNDAzMzFUMjMwMDAwWiAyMnF2cDkzamwxM3QyNDJucnNycGZjbjhtZ0Bn", :updated=>"2014-03-26T21:01:45.698Z", :summary=>"Mook ", :description=>"chamber group", :location=>"Sage Hall", :start=>{:dateTime=>"2014-03-31T19:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T20:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T19:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=N2owMzhqdGY3Y2tqajU2cTZqZWppdmFhaGNfMjAxNDAzMzFUMjEwMDAwWiAyMnF2cDkzamwxM3QyNDJucnNycGZjbjhtZ0Bn", :updated=>"2014-03-26T21:02:04.577Z", :summary=>"Gulley Group", :description=>"group", :location=>"Sage Hall", :start=>{:dateTime=>"2014-03-31T17:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T18:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T17:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=aHQ1N3NzbDJscWJidnBoZGQzYnUzNWw4aXNfMjAxNDAzMzFUMjExNTAwWiB2a2dpa3Q0bml0bmlrdmVlOWsycmFvdG03OEBn", :updated=>"2014-03-26T19:52:48.306Z", :summary=>"Moretti", :description=>"Moretti needs piano & guitar amp", :location=>"159", :start=>{:dateTime=>"2014-03-31T17:15:00-04:00"}, :end=>{:dateTime=>"2014-03-31T19:45:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T17:15:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=MWE5Zjc4OWlrMHRqNm1lOGgxdHNhdmlpcmtfMjAxNDAzMzFUMTkzMDAwWiBsa2s3ZGUyc2t0NTFpcHJjbmM4MWdhY2xyNEBn", :updated=>"2014-03-26T20:34:32.847Z", :summary=>"House", :location=>"124", :start=>{:dateTime=>"2014-03-31T15:30:00-04:00"}, :end=>{:dateTime=>"2014-03-31T19:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T15:30:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=bnByNnNndXJwcGFpdWFsczNiYTZucWtjMDRfMjAxNDAzMzFUMjAxNTAwWiA5ZmZiZWlxNzJxazdmMW01aDc0MzJ0bzZmc0Bn", :updated=>"2014-03-26T20:06:17.620Z", :summary=>"Faria", :location=>"140", :start=>{:dateTime=>"2014-03-31T16:15:00-04:00"}, :end=>{:dateTime=>"2014-03-31T18:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T16:15:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=Zm5wMm1qYXZmYzJmcXN1bHFzdWh0bTNpMDQgaTNib2o2dDd2MzhlMW82NG9qMTZodXJnMDBAZw", :updated=>"2014-03-26T21:06:39.327Z", :summary=>"Pina", :location=>"123", :start=>{:dateTime=>"2014-03-31T15:30:00-04:00"}, :end=>{:dateTime=>"2014-03-31T17:30:00-04:00"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=NmRqcmM4Yzk1czE0ZzgwZzVhaHA4anZzYTBfMjAxNDAzMzFUMjEzMDAwWiBpM2JvajZ0N3YzOGUxbzY0b2oxNmh1cmcwMEBn", :updated=>"2014-03-26T21:08:32.877Z", :summary=>"Hold", :description=>"Hold for new voice teacher Michael Garrepy, 5:30-9", :location=>"123", :start=>{:dateTime=>"2014-03-31T17:30:00-04:00"}, :end=>{:dateTime=>"2014-03-31T21:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T17:30:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=Y25vYnM2a3Y4c2ttYmE2dDQ3OXN0aWhoY2tfMjAxNDAzMzFUMjAwMDAwWiBlM2o5cHE4aWprZ3ByZG9yYnFvcTQzOHNwY0Bn", :updated=>"2014-03-26T20:05:07.885Z", :summary=>"Rondeau", :location=>"141", :start=>{:dateTime=>"2014-03-31T16:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T19:30:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T16:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=Z244dTFpMDN2YXBxbGpuZTZzNjBjNTk1M29fMjAxNDAzMzFUMTkzMDAwWiAwNW1ybWgyYzV0dXZhZWZhMDdiOXBtZzJyZ0Bn", :updated=>"2014-03-26T20:07:03.451Z", :summary=>"Chito", :location=>"139", :start=>{:dateTime=>"2014-03-31T15:30:00-04:00"}, :end=>{:dateTime=>"2014-03-31T17:30:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T15:30:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=Zzk1bmVzNWNscm1sZ2JyZGlmMmdvbnZtamtfMjAxNDAzMzFUMjAwMDAwWiA4YW5uamVhNXV2NXJmOXBzMWlpdmlyZDNpMEBn", :updated=>"2014-03-26T19:52:15.135Z", :summary=>"Marks", :description=>"Karen Marks has file cabinet in room", :location=>"162", :start=>{:dateTime=>"2014-03-31T16:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T19:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T16:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=b2g4bnBoNmxxOHVlc3V1MTQzOGgxZGUybDRfMjAxNDAzMzFUMTkzMDAwWiBhcWNxMTg4bjg4YzBuZGJjcWNvOG83anRyOEBn", :updated=>"2014-03-26T19:58:24.697Z", :summary=>"Izumoff", :description=>"2 grands: Baldwin (white piano) & Knabe", :location=>"146", :start=>{:dateTime=>"2014-03-31T15:30:00-04:00"}, :end=>{:dateTime=>"2014-03-31T19:45:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T15:30:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=NmMwOGU2Y2FjN2RsbWVkc2t0Y3FhNGxocTRfMjAxNDAzMzFUMjAzMDAwWiAzN291Y2M2bTNqZ3R2N2l0cjlkZ2lvbW9yb0Bn", :updated=>"2014-03-26T19:54:31.139Z", :summary=>"Chen", :description=>"no piano", :location=>"153", :start=>{:dateTime=>"2014-03-31T16:30:00-04:00"}, :end=>{:dateTime=>"2014-03-31T18:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T16:30:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=OGhoZ3Fhb2M0NDdkdjZwNnFpaDE5Z2xwYTRfMjAxNDAzMzFUMTg0NTAwWiBsdXRhNmptbDczOW1pMTZnZjRwYzZvaG1sc0Bn", :updated=>"2014-03-26T20:37:59.790Z", :summary=>"Bishop", :location=>"122", :start=>{:dateTime=>"2014-03-31T14:45:00-04:00"}, :end=>{:dateTime=>"2014-03-31T19:30:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T14:45:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=bjRyMGJ1Nmlnc2lqZGgwNzBrM2I2M280ZTBfMjAxNDAzMzFUMTkwMDAwWiBscHUwOTlqZWJkZnNzcjYxaWVrNXVvYWVtb0Bn", :updated=>"2014-03-26T20:01:54.474Z", :summary=>"Dingley", :description=>"2 Grands: both Steinways", :location=>"145", :start=>{:dateTime=>"2014-03-31T15:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T19:30:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T15:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=NHZlbjZiY2ZlZHZwajMyZWVwZGIxdjc1OHNfMjAxNDAzMzFUMjIwMDAwWiBoMzZvYzd1OXM3Z2xsbDZncDgzYTVlN3FnY0Bn", :updated=>"2014-03-26T20:40:39.253Z", :summary=>"Sanfilippo", :description=>"Combo", :location=>"115", :start=>{:dateTime=>"2014-03-31T18:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T19:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T18:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=cnVwaGI0aTI4MWdjOHJjOTQxbDJ2NGp1dTBfMjAxNDAzMzFUMTkwMDAwWiA2Y3MyNzZnaWllZGRia2Q3b2s0N2ZtODIzY0Bn", :updated=>"2014-03-26T19:51:32.955Z", :summary=>"Gulley", :location=>"163", :start=>{:dateTime=>"2014-03-31T15:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T19:45:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T15:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=dWQ4NjZja2l0NDhibGQ1cWFianVvcmFiNG9fMjAxNDAzMzFUMTk0NTAwWiA1ZTdxM3ZnNTFyNzBpYmNyYmQ2ajNqaWNvOEBn", :updated=>"2014-03-26T19:51:48.167Z", :summary=>"Herern", :location=>"158", :start=>{:dateTime=>"2014-03-31T15:45:00-04:00"}, :end=>{:dateTime=>"2014-03-31T19:30:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T15:45:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=cmR2YjBia2g0cW50NDVkc3E2YWFlZWRiMGNfMjAxNDAzMzFUMjMwMDAwWiBtanNubmkxMHFnajh2Mm5xMDk3MGNlcDczY0Bn", :updated=>"2014-03-26T20:57:46.446Z", :summary=>"RIPCO", :location=>"Large Hall", :start=>{:dateTime=>"2014-03-31T19:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T21:30:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T19:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=NDBjN3JrZGlzbHQ2cjFyamhrOHNjaWFqZnNfMjAxNDAzMzFUMTkwMDAwWiA5ZTdsa283ZDVxb3AxNWZmcThkaWoxZnF2NEBn", :updated=>"2014-03-26T20:07:57.186Z", :summary=>"Koch", :location=>"138", :start=>{:dateTime=>"2014-03-31T15:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T17:30:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T15:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=Y3NidG43cHA3a3Y0OTJxY2JocTUxaDVvbzAgdnBjdHFjcHRtZDdlbnQ4bjN2bnJnaXJpZGtAZw", :updated=>"2014-03-26T20:47:53.395Z", :summary=>"RIPCO String Quartet", :location=>"105", :start=>{:dateTime=>"2014-03-31T19:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T20:30:00-04:00"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=bnNxdXZmcTNuYjMyNDFsbnJ0cjhzYzVpdTRfMjAxNDAzMzFUMjEwMDAwWiB2cGN0cWNwdG1kN2VudDhuM3Zucmdpcmlka0Bn", :updated=>"2014-03-26T21:04:34.790Z", :summary=>"Hold ", :description=>"Hold for possible new Rondeau Suzuki group class", :location=>"105", :start=>{:dateTime=>"2014-03-31T17:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T18:30:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T17:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=aG1rNDBwbW1oZXRocjg3dGRjNmo4ajVpczhfMjAxNDAzMzFUMTIwMDAwWiB2cGN0cWNwdG1kN2VudDhuM3Zucmdpcmlka0Bn", :updated=>"2014-03-28T20:43:49.921Z", :summary=>"Bayview Rotating Schedule", :location=>"105", :start=>{:dateTime=>"2014-03-31T08:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T15:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T08:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=ODJvaXQ1NXN1YXE1ZHJyMnZkaWRjNGNobWdfMjAxNDAzMzFUMTIwMDAwWiBkNnA2bDFwZm04YjQwbDFxaGpvNnEybThzY0Bn", :updated=>"2014-03-26T20:44:19.991Z", :summary=>"PCD (rotating schedule)", :location=>"107", :start=>{:dateTime=>"2014-03-31T08:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T15:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T08:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=NWhxdGswNzZyNnY5czZyMGl1NzRnZ3NlMW9fMjAxNDAzMzFUMjEwMDAwWiBkNnA2bDFwZm04YjQwbDFxaGpvNnEybThzY0Bn", :updated=>"2014-03-26T20:45:19.398Z", :summary=>"Young", :description=>"chamber group 5-6pm", :location=>"107", :start=>{:dateTime=>"2014-03-31T17:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T18:30:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T17:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=c2VvMjNuYm01bGY1YWJlOXE0dGZlbzNvNmNfMjAxNDAzMzFUMjMwMDAwWiBkNnA2bDFwZm04YjQwbDFxaGpvNnEybThzY0Bn", :updated=>"2014-03-26T20:46:14.696Z", :summary=>"Klein", :description=>"Big Band", :location=>"107", :start=>{:dateTime=>"2014-03-31T19:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T20:30:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T19:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=MW5mOXJhNGhlYm5yZmwyNXVtMGhtMDRvaGNfMjAxNDAzMzFUMjIwMDAwWiA1YmdtY2xpMmpnNW1hZjBiZnBmbHFna2t2c0Bn", :updated=>"2014-03-26T20:03:25.113Z", :summary=>"Godfrey", :description=>"2 Grands: Sammick & Steinway (Steinway belongs to Gim family)", :location=>"144", :start=>{:dateTime=>"2014-03-31T18:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T20:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T18:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=ZGF2a3JsanVnNWRuNmZ0aGdkaTNmOWZlYm9fMjAxNDAzMzFUMTgxNTAwWiA4YmNtcG9mcjNydmszbmgydWI3MDE1MXBiMEBn", :updated=>"2014-03-26T20:28:07.302Z", :summary=>"Kullberg", :location=>"128", :start=>{:dateTime=>"2014-03-31T14:15:00-04:00"}, :end=>{:dateTime=>"2014-03-31T19:15:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T14:15:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=NzRlMzB2MmowYWlvZGhlYTRhY2c1aGpvYXMgdmV0OGdmNDFxZWRrNGFwZjBkbWd1MzU5M2tAZw", :updated=>"2014-03-26T19:52:58.165Z", :summary=>"Mook", :description=>"Quartet - Usually in Board Room - 178 (Johnson-Carhalho meeting 5-6:30 in board room on 3/31)", :location=>"156", :start=>{:dateTime=>"2014-03-31T17:30:00-04:00"}, :end=>{:dateTime=>"2014-03-31T18:30:00-04:00"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=cWMyZWx0amRjanZzc3JyZXBlMmJkdjYyaDRfMjAxNDAzMzFUMjIwMDAwWiBsa2pwZ3Vqcm1rYm0wYTJnZ2NiMm9zcjdqOEBn", :updated=>"2014-03-26T20:41:19.062Z", :summary=>"Miele", :location=>"114", :start=>{:dateTime=>"2014-03-31T18:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T19:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T18:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=ZzN1NDc0OXZjMXE4NTZsZWZ1bjE5NzFnMW9fMjAxNDAzMzFUMjM0NTAwWiA4dm9haXVwdWYxYWxsM2lwNzJzZ3NyZmdpY0Bn", :updated=>"2014-03-26T20:13:05.723Z", :summary=>"Bishop", :location=>"137", :start=>{:dateTime=>"2014-03-31T19:45:00-04:00"}, :end=>{:dateTime=>"2014-03-31T20:45:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T19:45:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=ZTAzamphdW9hcmNiZ29nazk5cDJyZGM0bXNfMjAxNDAzMzFUMTMwMDAwWiBvaGw4bjNuZXEzOGZvNmhnZWxmajJ1cWdpMEBn", :updated=>"2014-02-06T16:05:22.402Z", :summary=>"Gendron", :location=>"152", :start=>{:dateTime=>"2014-03-31T09:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T21:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T09:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=ZGoxMWM5ZDhrcmlibGlwZjdidjhoc2ExaWtfMjAxNDAzMzFUMTQwMDAwWiAxcjc5bTZqdWdrdGgwNTlqdjV0NXRhYjA1Z0Bn", :updated=>"2014-03-26T19:51:22.737Z", :summary=>"LLC (BCLIR)", :location=>"178", :start=>{:dateTime=>"2014-03-31T10:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T12:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T10:00:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=cXY4MmJsOTJyMnFrOGg4MWxqb3VhNG8wNzQgMXI3OW02anVna3RoMDU5anY1dDV0YWIwNWdAZw", :updated=>"2014-03-26T19:52:40.514Z", :summary=>"Johnson-Carvalho Meeting", :location=>"178", :start=>{:dateTime=>"2014-03-31T17:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T18:30:00-04:00"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=NGd2cDA5MGhjaGNyOW9uNzI1dGJvNWJ2ZDBfMjAxNDAzMzFUMTkzMDAwWiA0ZmU5cTk0bWhkbmNzNDY2bGZrMDhsdG0yb0Bn", :updated=>"2014-03-26T19:51:40.616Z", :summary=>"Mazonson", :description=>"Grand piano - Baldwin ", :location=>"161", :start=>{:dateTime=>"2014-03-31T15:30:00-04:00"}, :end=>{:dateTime=>"2014-03-31T19:45:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T15:30:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=N3Q4Mzdlb2I2aTBwdjZqcmJzc3VxdWxsMzRfMjAxNDAzMzFUMTkzMDAwWiA2NjBmdDdpcWJkbTlnbWwyYXZlZ2lsNnEwNEBn", :updated=>"2014-03-26T20:29:01.680Z", :summary=>"Norigian", :location=>"127", :start=>{:dateTime=>"2014-03-31T15:30:00-04:00"}, :end=>{:dateTime=>"2014-03-31T20:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T15:30:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=djgxMWJtNTVtNnI3MHJlbDFrbjE2bXUzYWdfMjAxNDAzMzFUMjAzMDAwWiBzOGxmczJrZGY0dGY1MnNvNGM5cXBhZ3Y3MEBn", :updated=>"2014-03-28T19:49:11.852Z", :summary=>"Temple", :description=>"Autism Project: Taylor Temple", :location=>"126", :start=>{:dateTime=>"2014-03-31T16:30:00-04:00"}, :end=>{:dateTime=>"2014-03-31T18:30:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T16:30:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=bDVoNmlwZjZxYmY5bmJjM2E3dDg2MDFkY2NfMjAxNDAzMzFUMjAxNTAwWiB2MXRhcXRjNWwxdHBiMzFscmRmY3NmOGdma0Bn", :updated=>"2014-03-26T19:52:31.711Z", :summary=>"Sanfilippo", :description=>"2 upright pianos", :location=>"165", :start=>{:dateTime=>"2014-03-31T16:15:00-04:00"}, :end=>{:dateTime=>"2014-03-31T18:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T16:15:00-04:00", :timeZone=>"America/New_York"}}, {:htmlLink=>"https://www.google.com/calendar/event?eid=NWtmcTB1MnBycHJ1ZWZlYjluMWRpaDRtODRfMjAxNDAzMzFUMjAwMDAwWiBxdHNkcWplOWk1ZTFpZG05MXVkZmJ2dHI4c0Bn", :updated=>"2014-03-26T19:52:03.005Z", :summary=>"Shabalin", :location=>"164 ", :start=>{:dateTime=>"2014-03-31T16:00:00-04:00"}, :end=>{:dateTime=>"2014-03-31T20:00:00-04:00"}, :originalStartTime=>{:dateTime=>"2014-03-31T16:00:00-04:00", :timeZone=>"America/New_York"}}]
  # data = data + data
  @post_date = "#{params[:post_date]}"
  @events = data.sort_by {|a,b| [a[:location], to_datetime(a[:start][:dateTime])]}
  haml :schedule
end


get '/pdf/:post_date' do |d|
  html = haml(:index)
  kit = PDFKit.new(html)
  # kit.stylesheets << '/css/print.css'
  pdf = kit.to_pdf
end









get '/events/:post_date' do |d|
  # File.truncate('debug.dbg', 0)
  File.write('debug.dbg', "")
  dbg("begin fetch")
  # Fetch list of calendar ids
  calendars = api_client.execute(:api_method => calendar_api.calendar_list.list,
                              :parameters => {'fields' => 'items/id'},
                              :authorization => user_credentials)
  dbg("fetch calendar list")
  calendars_json = calendars.data.to_json
  calendars_hash = MultiJson.load(calendars_json, :symbolize_keys => true)
  calendar_id_list = calendars_hash[:items]
  File.write('cal-ids-hash.dbg', calendar_id_list)
  @calIds = []
  if calendar_id_list
    calendar_id_list.each do |x|
      @calIds << x[:id]
    end
  else
    ["No Calendar"]
  end
  dbg("calids created")
  # dbg(@calIds)
  File.write('cal-ids.dbg',@calIds)
  # [all]
  # erb <hr>
  # erb ids(calendars)
  # for each cal id, pull event id
  # timeMin = "2014-03-31T04:00:00Z"
  # timeMax = "2014-04-01T04:00:00Z"
  if DateTime.strptime("#{d}","%Y-%m-%d").to_time.dst?
    timeZone = "-04:00"
  else
    timeZone = "-05:00"
  end
  
  dateIn = "#{d}"+"T00:00:00" + timeZone
  
  @timeMin = DateTime.strptime(dateIn)
  @timeMax = @timeMin.next
  dbg([@timeMin.strftime,@timeMax.strftime,])
  # dayMin = dateIn[8..10].to_i + 1
  # year = dateIn[0..3].to_i
  # dayMax = dateIn[0..7]  + dayMin.to_s
  # DateTime.new(2001,2,3,4,5,6,'-7').to_s
  # timeMax = DateTime.strptime(dayMax, '%F')
  # dbg([dateIn,dayMin, dayMax,timeMax])
  # [timeMin.to_s,timeMax.to_s]
  # timeMin = 
  event_ids = []
  events = []
  events_list = nil
  dbg('pull events')
  batch = Google::APIClient::BatchRequest.new do |result|
    events_list = result.data.to_json
    event = MultiJson.load(events_list, :symbolize_keys => true)
    events << event

  end

  elist = []
  events_list_batch = nil
  @calIds.each do |x|
  
    # events << "begin cal #{x}"
    events_list_batch = {:api_method => calendar_api.events.list,
                              :parameters =>  {'calendarId' => x, "timeMin" => @timeMin.strftime, "timeMax" => @timeMax.strftime, "orderBy" => "startTime", 'singleEvents' => "true",
                              "fields" => "items(description,htmlLink,location,originalStartTime,start,end,summary,updated)" },
                              :authorization => user_credentials}

    batch.add(events_list_batch)

  end

    # [elist.to_s]
    api_client.execute(batch,:authorization => user_credentials) 
    # events_list_json = events[:items].to_json
    # events_list_hash = MultiJson.load(events_list_json, :symbolize_keys => true)
    # [events_list_hash.to_s]
    @events = []
    events.each do |event|
        e = event[:items]
      e.each do |w|
      if w != nil
        @events << w
      end 

    end
    end
    dbg(@events)
    File.write('events.dbg',@events.to_s)

  #   # event_id = events_list_hash[:items]
  #   File.write('event-ids.dbg',events)
    # [events_list_json.to_s,elist.to_s]
    # event_id_count = event_id.length
    # n = 0
    # while n < event_id_count
    #   event_id[n].each do |key, id|
    #     event_ids << id
    #   end
    #   n = n+1
    # end
    # page_token = nil
    #   result = api_client.execute(:api_method => service.events.list,
    #                           :parameters => {'calendarId' => 'primary'})
    #   while true
    #     events = result.data.items
    #     events.each do |e|
    #       print e.summary + "\n"
    #     end
    #     if !(page_token = result.data.next_page_token)
    #       break
    #     end
    #     result = client.execute(:api_method => service.events.list,
    #                             :parameters => {'calendarId' => 'primary',
    #                                             'pageToken' => page_token})
    #   end
    
    # for y in event_ids do
    #   event = api_client.execute(:api_method => calendar_api.events.get,
    #                             :parameters => {'calendarId' => x, 'eventId' => y, "fields" => "description,htmlLink,location,originalStartTime,start,end,summary,updated" },
    #                             :authorization => user_credentials)
    #   event_data = event.data.to_json
    #   event_json = MultiJson.load(event_data, :symbolize_keys => true)
    #   unless event_json[:error]
    #     events << event_json
    #   end

      
    # end
  # File.write('event_ids.dbg', event_ids)
  # File.write('events.dbg', events)
  # [events.to_s]
  @eventsSort = []
   @eventsSort = @events.sort_by {|a|
    dbg(a)
    if a != nil
      if a[:location] !=nil
        dbg(a[:location]) 
        if a[:start][:dateTime] != nil 
          dbg(a[:start][:dateTime])
        [a[:location], to_datetime(a[:start][:dateTime])]
      end
      end
    end
    }
  # @eventsSort = @events
  dbg("DONE")
  haml :schedule
end
