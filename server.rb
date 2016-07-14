require 'rubygems'
require 'sinatra'
require 'twilio-ruby'

# put your default Twilio Client name here, for when a phone number isn't given
default_client = "charles"
# Add a Twilio phone number or number verified with Twilio as the caller ID
caller_id   = ENV['twilio_caller_id']
account_sid = ENV['twilio_account_sid']
auth_token  = ENV['twilio_auth_token']
appsid      = ENV['twilio_app_id_latency']

#callbackurl = "#{request.base_url}"  #use ngrok to access test page, not localhost



get '/' do
    client_name = params[:client]
    if client_name.nil?
        client_name = default_client
    end

    capability = Twilio::Util::Capability.new account_sid, auth_token
    # Create an application sid at twilio.com/user/account/apps and use it here
    capability.allow_client_outgoing appsid
    capability.allow_client_incoming client_name
    token = capability.generate
    erb :index, :locals => {:token => token, :client_name => client_name}
end

post '/conference' do
  response = Twilio::TwiML::Response.new do |r|
    r.Dial do |d|
      d.Conference "latencytest", :beep => "false"
    end
  end
  response.text

end

post '/monitor' do
  #check some variable, do you really want to move this call into conference once it has ended?
  response = Twilio::TwiML::Response.new do |r|
    r.Dial do |d|
      d.Conference "latencytest", :beep => "false"
    end
  end
  response.text
end

post '/modifycall' do
  #params - accept parent leg of the call
  #modify the call leg to move to conference
  #if this request is coming from a twilio client, get clientcallsid, then get parent, then modify the parent
  callSid = params[:callSid]
  @client = Twilio::REST::Client.new account_sid, auth_token


  @client.account.calls.get(callSid).update({
	   :url =>  "#{request.base_url}" + '/monitor',
  })

end

post '/dialpstn' do
  #this will be called if the agent is called on PSTN
  number = params[:AgentNumber]
  customernumber = params[:CustomerNumber]
  @client = Twilio::REST::Client.new account_sid, auth_token

  call = @client.account.calls.create({
       :to => number,
       :from => caller_id,
       :url =>  "#{request.base_url}" + "/callcustomer?CustomerNumber=#{customernumber}&AgentNumber=#{number}"
  })


  puts "got a request to call agent on #{number}, who then will call #{customernumber} from twiml with call sid #{call.sid}"
  return call.sid

end

post '/callcustomer' do
  number = params[:CustomerNumber]
  agentnumber = params[:AgentNumber]
  response = Twilio::TwiML::Response.new do |r|
    r.Dial :callerId => agentnumber, :action => "#{request.base_url}" + "/monitor" do |d|
      d.Number number
    end
  end
  response.text

end


post '/getchildcallsidfromparent' do
  parentcallsid = params[:parentcallsid]
  childcall = ""
  @client = Twilio::REST::Client.new account_sid, auth_token

  @client.account.calls.list({:parentCallSid => parentcallsid, }).each do |call|
	   puts "child call = #{call.sid}"
     childcall = call.sid
  end

  return childcall

end



post '/clientappconnect' do
      number = params[:PhoneNumber]
      response = Twilio::TwiML::Response.new do |r|
        r.Dial :callerId => caller_id, :action => "/monitor" do |d|
          d.Number number
        end
      end


    response.text
end

#
