require 'uri'
require 'net/http'

module Ruote

  # This class is responsible for finding and manipulating work items
  class WorkItem < Ruote::Base

    #include Comparable
    include HTTParty

    @@path_separator = '/'
    cattr_accessor :path_separator

    class << self

      # Return the number of work items for the participant
      def count( participant )
        begin
          find( :all, :participant => participant ).size
        rescue Errno::ECONNREFUSED
          0
        end
      end

      def find( *args )
        options = args.extract_options!

        return case args.first
        when Symbol
          limit = args.shift
          if limit == :all
            find_by_participant( options[:participant] )
          elsif limit == :first
            find_by_participant( options[:participant] ).shift
          elsif limit == :last
            find_by_participant( options[:participant] ).pop
          else
            raise NotImplementedError, "Limit #{limit} not implemented"
          end
        else
          find_by_id( args.first )
        end
      end

      # Find work items for the +participant+
      def find_by_participant( participant )
        participant = object_participant_name( participant )

        if enabled?
          response = get( '/workitems', :query => { :participant => participant, :format => 'json' }, :format => :json )
          response['elements'].map { |r| new( r ) }
        else
          []
        end
      end

      # Find a specific work item by id
      def find_by_id( id )
        id = self.decode_url_id( id, true )

        if enabled?
          begin
            new(
              get('/workitems/' + id + '.json')
            )
          rescue Net::HTTPServerException => e
            nil
          end
        else
          nil
        end
      end

      # Join the id and expression_id of a #WorkItem in a Rails-friendly fashion
      def encode_url_id( id, expression_id, escape = false )
        id = [ id, expression_id .gsub('.', '_') ].join(self.path_separator)
        escape ? URI.escape( id, './' ) : id
      end

      # Decode the provided path snippet back into a ruote-rest friendly id
      def decode_url_id( id, underscore_expression_id = false )
        id = URI.unescape( id )
        underscore_expression_id ? id.gsub('.', '_') : id.gsub('_', '.')
      end
    end

    # Proxy these methods to our internal workitem
    [ :last_modified, :participant_name, :dispatch_time, :attributes,
      :flow_expression_id, :links ].each do |proxy_method|
      define_method proxy_method do
        eval "@work_item[ '#{proxy_method.to_s}' ]"
      end
    end

    # Setup from a JSON-encoded OpenWFE::InFlowWorkItem
    def initialize( json_work_item )
      reset_object_using( json_work_item )
    end

    def reload
      reset_object_using get( self.uri )
    end

    # Quick access to our payload
    def []( key )
      self.attributes[key.to_s]
    end

    # Quick access to our payload
    def []=( key, value )
      self.attributes[key.to_s] = value
    end

    def id
      @work_item['flow_expression_id']['workflow_instance_id']
    end

    def expression_id
      @work_item['flow_expression_id']['expression_id']
    end

    # Access to the params attribute
    def params
      self[:params] || {}
    end

    # Return the associated model by looking at attributes[:model][:class] and
    # attributes[:model][:id]. Pass additional args to ActiveRecord::Base#find
    def model( *args )
      return nil if self['model'].blank? || self['model']['class'].blank? || self['model']['id'].blank?

      self['model']['class'].constantize.find( self['model']['id'], *args )
    end

    # Return the URI of the workitem for performing updates
    def uri
      self.links.detect { |l| l['rel'] == 'self' }['href']
    end

    # Return the protocol, host, port version of #uri
    def host
      full_uri = URI.parse( self.uri )
      full_uri.to_s.gsub( full_uri.path, '' )
    end

    def name
      self.flow_expression_id['workflow_definition_name']
    end

    def activity
      self.params['activity']
    end

    # Return true if there is an api_error present in the attributes
    def api_error?
      !self['api_error'].blank?
    end

    # Returns the api error or a blank string
    def api_error
      self['api_error'] || ''
    end

    # Returns true if the process has been postponed
    def postponed?
      self['postpone']
    end

    # Save changes without proceeding
    def update!
      @update_called = true
      self.class.put( uri, :body => self.to_json )
      nil
    end

    # Save changes and proceed
    def proceed!
      @proceed_called = true
      self['_state'] = 'proceeded'
      self.class.put( uri, :body => self.to_json, :headers => { 'Content-Type' => 'application/json'} )
      nil
    end

    # Cancel the process that this workitem is a part off
    def cancel_process!
      @cancel_process_called = true
      self.class.delete( host + '/processes/' + self.id  + '.json')
      nil
    end

    def to_param( escape = true )
      self.class.encode_url_id(self.id, self.expression_id, escape)
    end

    def to_json
      ActiveSupport::JSON.encode( @work_item )
    end

    def ==( other )
      other.is_a?( self.class ) ? self.id == other.id : false
    end

    def new_record?
      false
    end

    # Lazily load the expression tree for this process from ruote-rest so we
    # can display it using ruote-fluo
    def expression_tree( decode = false )
      query = decode ? {} : { :query => { :plain => 'true' } }
      @expression_tree ||= self.class.get( "/processes/#{self.id}/tree.json", query )
    end

    def created_at
      Time.parse( self.dispatch_time )
    end

    def updated_at
      Time.parse( self.last_modified )
    end

    private

    def reset_object_using( json_work_item )
      @work_item = ( json_work_item.is_a?(String) ? ActiveSupport::JSON.decode( json_work_item ) : json_work_item )

      @work_item['attributes'] ||= {}

      @changed = false
    end
  end
end
