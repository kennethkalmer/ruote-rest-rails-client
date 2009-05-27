module Ruote

  # Allow easy process launching by using ActiveRecord callbacks to trigger
  # specified process definitions. See #launch_processes for more information
  module ProcessLauncher

    def self.included( base ) #:nodoc:
      base.extend( ClassMethods )
    end

    module ClassMethods

      # Specify process definitions to launch during the ActiveRecord object
      # lifecycle.
      #
      # Non-lifecycle options:
      # * payload => Symbol or Proc
      # * participants => Symbol or Proc
      # * event => Symbol
      # * state => String
      # * provision_check => Symbol
      #
      # To obtain the payload for the process launch, either a method (Symbol)
      # or Proc (with self yielded) will be called. Processes can be launched
      # without a payload. Payloads are expected to be hashes.
      #
      # To obtain the list of participants in the process, either a method
      # (Symbol) or Proc (with self yielded) will be called. Process can be
      # launched without a list of participants, which will let the process
      # definition itself specify the participants. Participants are expected
      # to be hashes.
      #
      # Specifying :event will have the process launcher call the
      # event on the instance, useful to toggle the state of the model
      # when a process is launched.
      #
      # Specifying :state will have the process launcher set the
      # 'state' attribute directly to the new state, without calling
      # an event. Useful when processes are launched during the
      # lifecycle of a model.
      #
      # Setting :provision_check to a method name will have the process      
      # launcher add a 'self_provision' attribute to the payload based on the
      # result of calling the method on the +process_intiator+
      # variable (true/false). If +provision_check+ is not set, the
      # attribute will default to false.
      #
      # Lifecycle options are:
      # * :create  => definition
      # * :update  => definition
      # * :save    => definition
      # * :destroy => definition
      #
      # Each of the above options are used as after_* callbacks on the model.
      #
      # definition, as the value of the options hash can be anyone of the
      # following:
      #
      # * String: directly interpreted as the process definition name
      # * Symbol: method to be called to obtain process definition name
      # * Proc:   called with +self+ as parameter, expects process definition
      #   name to be returned
      #
      # If the definition is nil or a blank string, no process will be launched.
      #
      def launch_processes( options = {} )
        return if self.included_modules.include?( Ruote::ProcessLauncher::InstanceMethods )
        
        options.stringify_keys!
        options.reverse_merge({
          # defaults (if any)
        })

        options.assert_valid_keys( 'payload', 'participants', 'create', 'update', 'save', 'destroy', 'event', 'state', 'provision_check' )

        class_inheritable_accessor :ruote_process_launcher_options
        self.ruote_process_launcher_options = options
        
        # Track our enabled/disabled flags
        class_inheritable_reader :processes_enabled
        
        # register callbacks
        %w{ create update save destroy }.each do |key|
          if self.ruote_process_launcher_options.has_key?( key )
            send( "after_#{key}".to_sym, "ruote_after_#{key}".to_sym )
          end
        end
        
        extend SingletonMethods
        include InstanceMethods
        
        # Used to track who started the process
        attr_accessor :process_initiator
        
        # Enable by default
        write_inheritable_attribute :processes_enabled, true
      end
    end

    module SingletonMethods

      # Prevent processes from being called during block execution
      def without_processes(&block)
        processes_was_enabled = processes_enabled
        begin
          disable_processes
          return block.call
        ensure
          enable_processes if processes_was_enabled
        end
          #returning(block.call) { enable_processes if processes_was_enabled }
      end

      def disable_processes
        write_inheritable_attribute :processes_enabled, false
      end
        
      def enable_processes
        write_inheritable_attribute :processes_enabled, true
      end
    end

    module InstanceMethods
      
      # Prevents processes from launching during the block call
      def without_processes(&block)
        self.class.without_processes(&block)
      end
      
      # Get the payload for the model
      def ruote_payload
        payload_option = self.class.ruote_process_launcher_options['payload']
        payload = ruote_parse_option( payload_option, {} )
        
        # provision checks
        provision_check = self.class.ruote_process_launcher_options['provision_check']
        if provision_check.nil?
          payload.merge!( 'self_provision' => true )
        elsif self.process_initiator.nil?
          payload.merge!( 'self_provision' => true )
        else
          payload['self_provision'] = ( self.process_initiator.respond_to?( provision_check ) ? self.process_initiator.send(provision_check) : true )
        end
        
        payload.merge!( 'model' => { 'class' => self.class.to_s, 'id' => self.id }, 'itag' => self.itag )
      end

      def ruote_after_create #:nodoc:
        ruote_callback( 'create' )
      end

      def ruote_after_update #:nodoc:
        ruote_callback( 'update' )
      end

      def ruote_after_save #:nodoc:
        ruote_callback( 'save' )
      end

      def ruote_after_destroy #:nodoc:
        ruote_callback( 'destroy' )
      end
      
      # An ETag implementation, but for tagging process payloads to
      # simplify searches
      def itag
        Ruote::Base.object_participant_name( self )
      end

      # Manage the callback at specified event
      def ruote_callback( event )
        if option = self.class.ruote_process_launcher_options[ event ]
          process_definition = ruote_parse_option(option)

          unless process_definition.blank?
            participants_option = self.class.ruote_process_launcher_options['participants']
            participants = ruote_parse_option( participants_option, {} )

            ruote_launch_process( process_definition, participants )
          end
        end
      end

      # Launch a ruote process by name and with the specified participants and
      # payload. Returns the instance of #Ruote::Process used, or will throw
      # an exception if something went wrong.
      # 
      # If :event was passed to the initial options, it will be fired
      # here. If :state was passed, it will be changed here.
      def ruote_launch_process( process_name, participants = {}, payload = {} )
        # Don't run even not required
        return unless processes_enabled
        
        process = Process.new( process_name, participants )
        process.launch!( payload.reverse_merge( ruote_payload ) )
        
        if event = self.class.ruote_process_launcher_options['event']
          self.send( event )
        end

        if new_state = self.class.ruote_process_launcher_options['event']
          self[:state] = new_state
        end
        
        process
      end

      private

      # Parse the whole String/Symbol/Proc deal
      def ruote_parse_option( option, default = nil )
        case option
        when String
          option
        when Symbol
          send( option )
        when Proc
          option.call( self )
        else
          default
        end
      end

    end

  end
end

ActiveRecord::Base.send( :include, Ruote::ProcessLauncher )
