module Ruote
  
  # Common functionality shared by our wrapper classes, built on HTTParty
  class Base
    # configuration data
    cattr_reader :configuration
    @@configuration = nil
    
    # logger to use
    cattr_reader :logger
    @@logger = RAILS_DEFAULT_LOGGER
   
    class << self
      
      # Accept our configuration data
      def configuration=( options = {} )
        @@configuration = options
        
        LaunchJob.base_uri self.configuration.uri.host + ':' + self.configuration.uri.port.to_s
        WorkItem.base_uri self.configuration.uri.host + ':' + self.configuration.uri.port.to_s
      end
      
      def logger=( logger )
        @@logger = logger
      end

      def enabled?
        self.configuration.enabled
      end

      # Convert an object into a dynamic participant name
      def object_participant_name( object )
        case object
        when Symbol, String
          object.to_s.dasherize
        else
          (object.class.to_s + '-' + object.id.to_s).downcase
        end
      end
      
    end

    # Proxy these methods back to self.class
    [ :logger, :enabled?, :object_participant_name ].each do |proxy_method|
      define_method( proxy_method ) do |*args|
        self.class.send( proxy_method, *args )
      end
    end

  end
end
