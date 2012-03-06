require './client'
Bundler.require(:test)
RSpec.configure do |config|
  config.include WebMock::API
end

describe Reader do  
  it "should error if the RFID scanner is not present" do
    fail "DO NOT TEST WITH DEVICE PLUGGED IN" if File.exists?("/dev/tty.usbserial-A6009nts")
    expect { Reader::scan }.to raise_error(Errno::ENOENT) 
  end
  
  it "should return the RFID ID" do
    # Mock SerialPort
    SerialPort.stub(:open) {StringIO.new("asdf1234")}
    Reader::scan.read.should == "asdf1234"
  end
end

describe Event do
  before do
    stub_request(:post, "https://csebark.herokuapp.com/auth/login").
      with(:body => {"student_id"=>"test", "password"=>"testpassword"}).
      to_return(:status => 200, :body => {:status => "LOGGED_IN"}.to_json, :headers => {:content_type => 'application/json'})
      
    @client = WebClient.new("https://csebark.herokuapp.com", "test", "testpassword")
    @client.stub(:events) {[Event.new(:name => "bbq", :client => @client, :id => "1")]}
    @event = @client.events.first
  end
  
  it "should create new event objects" do
    event = Event.new(:name => "bbq", :client => @client)
    event.name.should == "bbq"
  end
  
  it "should check_in the member if it was a member with an RFID id" do
    stub_request(:post, "https://csebark.herokuapp.com/api/v1/checkin").
      with(:body => {:rfid => "asdf1234", :event_id => "1"}).
      to_return(:status => 200, :body => {:status => "CHECKED_IN", :user => {:name => 'bob'}})
        
    @event.check_in_with_rfid("asdf1234").body.should == {:status => 'CHECKED_IN',
      :user => {:name => 'bob'}
    }
  end
    
  it "should check in the member if it was a member with an student id" do
    stub_request(:post, "https://csebark.herokuapp.com/api/v1/checkin").
      with(:body => {:student_id => "asdf1234", :event_id => "1"}).
      to_return(:status => 200, :body => {:status => "CHECKED_IN", :user => {:name => 'bob'}})
    
    @event.check_in_with_student_id("asdf1234").body.should == {:status => 'CHECKED_IN',
      :user => {:name => 'bob'}
    }
  end
    
  it "should reject an invalid rfid response (e.g. credit card)" do
    stub_request(:post, "https://csebark.herokuapp.com/api/v1/checkin").
      with(:body => {:rfid => "asdf1234", :event_id => "1"}).
      to_return(:status => 403, :body => {:status => "INVALID"})
    
    @event.check_in_with_rfid("asdf1234").body.should == {:status => "INVALID"}
  end
  
  it "should promopt the user to enter details to sign up the member" do
    stub_request(:post, "https://csebark.herokuapp.com/api/v1/checkin").
      with(:body => {:rfid => "not_a_member", :event_id => "1"}).
      to_return(:status => 403, :body => {:status => "NOT_MEMBER"})
    
    @event.check_in_with_rfid("not_a_member").body.should == {:status => "NOT_MEMBER"}
  end
  
end

describe WebClient do
  before do
    # Login stub
    stub_request(:post, "https://csebark.herokuapp.com/auth/login").
      with(:body => {"student_id"=>"test", "password"=>"testpassword"}).
      to_return(:status => 200, :body => {:status => "LOGGED_IN"}.to_json, :headers => {:content_type => 'application/json'})
  end
  
  it "should log in an admin user" do
    client = nil
    expect do
      client = WebClient.new("https://csebark.herokuapp.com", "test", "testpassword")
    end.to_not raise_error
  end
  
  it "should reject a non-admin user" do
    stub_request(:post, "https://csebark.herokuapp.com/auth/login").
      with(:body => {"student_id"=>"test", "password"=>"wrongpassword"}).
      to_return(:status => 403, :body => {:error => "INVALID"}.to_json, :headers => {:content_type => 'application/json'})
    
    expect do
      client = WebClient.new("https://csebark.herokuapp.com", "test", "wrongpassword")
    end.to raise_error(WebClient::InvalidLogin)
  end
  
  it "should provide the client a list of events" do
    stub_request(:get, "https://csebark.herokuapp.com/api/v1/events").
      to_return(:status => 200, :body => {:events => [
        {:name => "bbq"},
        {:name => "beta"}
      ]}.to_json, :headers => {:content_type => 'application/json'})
    
    client = WebClient.new("https://csebark.herokuapp.com", "test", "testpassword")
    client.events.to_json.should == [
      Event.new(:name => "bbq", :client => client),
      Event.new(:name => "beta", :client => client)
    ].to_json
  end
  
  describe "signing up members" do
    
    before do
      @client = WebClient.new("https://csebark.herokuapp.com", "test", "testpassword")
    end
    
    it "should register a user if the details are correct" do
      stub_request(:post, "https://csebark.herokuapp.com/api/v1/register").
        with(:body => {:name => 'maxs'}).
        to_return(:status => 200, :body => {:status => "REGISTERED"}, 
        :headers => {:content_type => 'application/json'})
    
      @client.register_user(:name => 'maxs').body.should == {:status => "REGISTERED"}
    end
    
    it "should display the errors with registering a user" do
      stub_request(:post, "https://csebark.herokuapp.com/api/v1/register").
        with(:body => {:name => 'ritwikr'}).
        to_return(:status => 403, :body => {:status => "INVALID",
          :reason => {:student_id => "taken"}},
        :headers => {:content_type => 'application/json'})
      
      @client.register_user(:name => 'ritwikr').body.should == {
        :status => "INVALID",
        :reason => {:student_id => "taken"}
      }
    end
  end
  
end
