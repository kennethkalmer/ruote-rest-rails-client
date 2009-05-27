module Ruote
  # Serializable object for delayed_job friendliness, and HTTParty
  # injection into ruote-rest.
  class LaunchJob < Struct.new( :process_def, :fields )

    include HTTParty

    def perform
      RAILS_DEFAULT_LOGGER.info "[JOB] Launching delayed process"
      result = self.class.post('/processes', :body => { :pdef => process_def, :fields => fields }, :format => :xml )
      RAILS_DEFAULT_LOGGER.info "[JOB] Launch results: #{result.inspect}"
    end
  end
end
