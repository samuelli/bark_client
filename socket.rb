require './client'
require 'em-websocket'

class WSConnection < EventMachine::WebSocket::Connection
  def trigger_on_open
    @@clients ||= []
    @@clients << self
  end
  
  def trigger_on_close
    @@clients.delete self
  end
  
  def trigger_on_message(msg)
    msg = JSON.parse(msg)
    if msg[:method] = 'rfid'
      sign_in_with_rfid(msg[:value])
    elsif register
      register
    end
  end
  
  # Static
  def self.send_status(string)
    @@clients ||= []
    @@clients.each do |c|
      c.send string
    end
  end
  
end

EventMachine.run do
  EventMachine.start_server("0.0.0.0", 9293, WSConnection, {:debug => true})
  EventMachine::PeriodicTimer.new(0.5) do
    begin
      WSConnection::send_status Reader::scan
      sleep 1
    rescue Errno::ENOENT => ex
      WSConnection::send_status "Scanner not plugged in"
      sleep 5
    end
  end
end
