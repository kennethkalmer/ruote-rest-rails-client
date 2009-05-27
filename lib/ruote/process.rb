require 'erb'

module Ruote

  # Wrapper around launching our processes inside ruote-rest.
  class Process < Ruote::Base

    attr_reader :process_name, :job
    attr_accessor :participants
    attr_accessor :fields

    # Get ready to launch a specific process definition from file
    def initialize( process_name, participants = {} )
      @process_name = process_name
      @participants = participants
      @fields = {}

      raise ArgumentError, "Could not find process definition #{self.process_name}" unless self.exist?
    end

    # Launch the process in the background using delayed_job
    def launch!( fields = {} )
      logger.info "Launching process #{self.inspect} with payload: #{fields.inspect}"

      # Keep our payload available inspection
      @fields.merge! fields

      # Always be successful if not enabled
      if !enabled?
        @job = 'disabled'
        return @job
      end

      begin
        @job = Delayed::Job.enqueue LaunchJob.new( self.parse, ActiveSupport::JSON.encode( @fields ) )
        logger.info( "Launched process #{self.process_name}" )
        logger.debug( "#{self.process_name}: #{self.job.inspect}" )
      rescue => e
        @job = e
        logger.error( "Failed to launch process #{self.process_name}: #{e.message}" )
        logger.debug( e.backtrace.join(', ') )
      end

      @job
    end

    def exist?
      erb? || File.exist?( self.full_path )
    end

    def full_path
      File.join( RAILS_ROOT, 'app', 'processes', self.process_name )
    end

    def erb?
      return true if self.process_name =~ /\.erb$/

      if File.exists?( self.full_path + '.erb' )
        @process_name << '.erb'
        return true
      end

      false
    end

    def parse
      definition_string = IO.read( self.full_path )

      if erb?
        ERB.new( definition_string ).result( binding )
      else
        definition_string
      end
    end

    def get_participant( name )
      participant = self.participants[name] or raise ArgumentError, "Participant #{name} not found"

      object_participant_name( participant ).gsub('-', '_')
    end

    def get_field( name )
      @fields[ name.to_s ]
    end

    def inspect
      "#{self.class.to_s}(process_name: #{self.process_name}, participants: #{self.participants.inspect}, job: #{self.job.inspect})"
    end

  end
end
