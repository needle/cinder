module Cinder


  # == Usage
  #
  #   campfire = Cinder::Campfire.new 'mysubdomain', :ssl => true
  #   campfire.login 'myemail@example.com', 'mypassword'
  #   campfire.set_room 'Room Name'
  #   campfire.retrieve_transcript date
  class Campfire
    attr_reader :subdomain, :uri, :room
    
    # Create a new connection to a campfire account with the given +subdomain+.
    # There's an +:ssl+ option to use SSL for the connection.
    #
    # campfire = Cinder::Campfire.new("my_subdomain", :ssl => true)
    def initialize(subdomain, options = {})
      options = { :ssl => false }.merge(options)
      @subdomain = subdomain
      @uri = URI.parse("#{options[:ssl] ? "https" : "http"}://#{subdomain}.campfirenow.com")
      @room = nil
      @agent = WWW::Mechanize.new
      @logged_in = false
    end

    # Log in to campfire using your +email+ and +password+
    def login(email, password)
      unless @agent.post("#{@uri.to_s}/login", "email_address" => email, "password" => password).uri == @uri
        raise Error, "Campfire login failed"
      end
      @lobby = @agent.page
      @rooms = get_rooms(@lobby)
      @logged_in = true
    end

    # Returns true if currently logged in
    def logged_in?
      @logged_in == true
    end

    # Logs out of the campfire account
    def logout 
      if @agent.get("#{@uri}/logout").uri == URI.parse("#{@uri.to_s}/login")
        @logged_in = false
      end
    end

    # Selects the room with name +room_name+ to retrieve transcripts from
    def set_room(room_name)
      @room = find_room_by_name(room_name)
    end

    # Retrieve the transcript for the +date+ passed in as a Time object, and store it locally as a csv file
    def retrieve_transcript(date)
      transcript_uri = URI.parse("#{@room[:uri].to_s}/transcript/#{date.year}/#{date.month}/#{date.mday}")
      transcript_page = @agent.get(transcript_uri.to_s)
      transcript = transcript_page.parser
      write_transcript(transcript, "campfire_#{@room[:name]}_#{date.month >= 10 ? date.month : "0#{date.month}"}_#{date.mday >= 10 ? date.mday : "0#{date.mday}"}_#{date.year}")
    rescue WWW::Mechanize::ResponseCodeError
    end

    # Retrieve the transcripts from the +date+ passed in as a Time object, up until and including the current date
    def retrieve_transcripts_since(date)
      retrieve_transcripts_between(date, Time.now.utc)
    end
    
    # Retrieve the transcripts created between the +start_date+ and +end_date+ passed in as a Time objects
    def retrieve_transcripts_between(start_date, end_date)
      while !(start_date.year >= end_date.year and start_date.month >= end_date.month and start_date.mday > end_date.mday)
        puts start_date
        retrieve_transcript(start_date)
        start_date = start_date + 24*60*60
      end
    end

    private

    # Find all of the room names and associated urls on the provided +page+
    def get_rooms(page)
      page.links.collect { |link| { :name => link.to_s, :uri => link.uri } if link.uri.to_s["#{uri.to_s}/room"] }.reject { |room| room.nil? }
    end

    # Find the room name and uri hash that matches the provided +room_name+
    def find_room_by_name(room_name)
      @rooms.collect { |room| room if room[:name] == room_name }.reject { |room| room.nil? }.first
    end
    
    # Parse the provided +transcript+ hpricot document and write the contents to the .csv file +file_name+
    def write_transcript(transcript, file_name)
      writer = CSV.open("#{file_name}.csv", 'w')
      writer << ["Date", "Time", "User", "Message"]
      date = nil
      time = nil
      user = nil
      (transcript%"tbody[@id='chat']").each_child do |row|
        if row.class == Hpricot::Elem
          row.each_child do |cell|
            if cell.class == Hpricot::Elem
              if cell.classes.include? "date"
                if cell.containers.any?
                  date = cell.containers.first.html
                else
                  date = cell.html
                end
              elsif cell.classes.include? "time"
                if cell.containers.any?
                  time = cell.containers.first.html
                else
                  time = cell.html
                end
              elsif cell.classes.include? "person"
                if cell.containers.any?
                  user = cell.containers.first.html
                else
                  user = cell.html
                end
              elsif cell.classes.include? "body"
                writer << [date, time, user, cell.containers.first.html]
              end
            end
          end
        end
      end
      writer.close
    end

  end
end
