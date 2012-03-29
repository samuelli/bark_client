#!/usr/bin/env ruby

require './client'

@client = WebClient.new(ENV["CSE_HOST"], ENV["CSE_USERNAME"], ENV["CSE_PASSWORD"])
events = @client.events

events.each_with_index do |event, i|
  puts "#{i}. #{event.name}"
end

if events.any?
  print "Select an event: ".yellow
  selected = gets.to_i
  if selected < events.count
    @event = events[selected]
  else
    puts "Invalid Event"
    exit
  end
else
  puts "No Events"
  exit
end

def scan_card(result, rfid)
  if result['status'] == 'CHECKED_IN'
    puts "Checked in!".green.bold
    puts "Name: #{result['account']['name']}\n"
    puts "Student Id: #{result['account']['student_id']}\n"
    puts "Program: #{result['account']['program']}\n"
    if result['account']['cse_id']
      puts ("CSE ID: #{result['account']['cse_id']}").green.bold
    else
      puts "CSE ID: Not a CSE Student\n".red.bold
    end
  
  elsif result['status'] == 'NOT_MEMBER'
    puts "Not Registered".red
    if rfid
      print "Register user with card #{rfid} (y/n): ".yellow
      f = gets.chomp
      if f == "y"
        print "Student ID: ".yellow
        student_id = gets.chomp
        reg_result = @client.register_user(:student_id => student_id, :rfid => rfid).body
        if reg_result['status'] == "REGISTERED"
          scan_card(@event.check_in_with_rfid(rfid).body, rfid)
        else
          puts "Failed to register user - #{result[:reason]}".red
        end
      end
    end

  elsif result['status'] == 'INVALID'
    puts "Invalid Card - #{result['reason']}".red
    
  else
    puts "SCAN_ERROR - #{result.inspect}".red
    
  end
  puts

end

begin
  while true
    puts "Scan a card!".green
    rfid = Reader::scan
    Thread.new do
      `afplay /System/Library/Sounds/Ping.aiff`
    end
    puts "Loading...".yellow
    result = @event.check_in_with_rfid(rfid).body
    scan_card(result, rfid)
  end
rescue Errno::ENOENT => ex
  puts "Card reader not detected".red
  puts "Student number entry mode only".red
  
  while true
    print "Enter student number: ".yellow
    student_id = gets.chomp
    result = @event.check_in_with_student_id(student_id).body
    scan_card(result, nil)
  end
end
