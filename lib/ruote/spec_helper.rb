require 'uri'

module Ruote
  # Collection of helpers for mocking/stubbing out ruote-rest interactions
  module SpecHelper

    def stub_find_wi_by_id( wi )

      url = '/workitems/' + WorkItem.encode_url_id(wi.id, wi.expression_id) + '.json'
      WorkItem.expects(:get).with(url).returns(  wi.to_json )
      WorkItem.expects(:enabled?).returns(true)
    end

    def stub_find_by_participant( participant, *results )
      url_params = [ '/workitems', {
          :query => { :participant => Base.object_participant_name( participant ), :format => 'json' },
          :format => :json
        }]

      no_results = { 'elements' => [] }
      WorkItem.stubs(:get).with(any_parameters).returns(no_results)

      results = { 'elements' => results.map(&:to_json) }
      WorkItem.stubs(:get).with(*url_params).returns(results)

      WorkItem.stubs(:enabled?).returns(true)
    end

    # Setup a complicated expectation for the launching of ruote processes
    def expects_process( name, participants, payload )
      # Make sure the process exists
      definition = "#{RAILS_ROOT}/app/processes/#{name}"
      unless ( File.exists?( definition ) || File.exists?( definition << '.erb' ) )
        violated "#{definition} not found"
      end

      # Our mock
      fake_process = Object.new

      # Our participants
      Ruote::Process.expects(:new).with( name, participants ).returns( fake_process )

      # Our launch
      fake_process.expects(:launch!).with( payload )
    end

    # Ensure the specified process is never called
    def never_launch_process( name )
      Ruote::Process.expects(:new).with( name, anything ).never
    end

    # Args: participant, [[workflow_definition_name], model], {attributes}, {params}
    def mock_work_item( *args )

      # Get these guys off the end of the list
      attributes = extract_params_and_attributes(args)

      # pick out the participant
      participant = args.shift
      raise ArgumentError, "Participant object expected as first argument" if participant.nil?
      participant = Base.object_participant_name( participant )

      workflow_definition_name, model = extract_workflow_definition_and_model(args)

      unless model.nil?
        attributes['model'] = { 'class' => model.class.to_s, 'id' => model.id }
      end

      fake_json_work_item = generate_fake_json_work_item(attributes, participant, workflow_definition_name)

      WorkItem.any_instance.stubs(:proceed!).returns(nil)
      WorkItem.any_instance.stubs(:update!).returns(nil)
      WorkItem.any_instance.stubs(:cancel_process!).returns(nil)
      WorkItem.any_instance.stubs(:expression_tree).returns('')

      WorkItem.new( fake_json_work_item )
    end

    # TODO Comment
    def extract_workflow_definition_and_model(args)
      workflow_definition_name = args.shift

      if workflow_definition_name.kind_of?( ActiveRecord::Base )
        model = workflow_definition_name
        workflow_definition_name = nil
      else
        model = args.shift
      end

      return workflow_definition_name, model
    end

    # TODO Comment
    def extract_params_and_attributes(args)
      params = args.extract_options!
      attributes = args.extract_options!

      attributes, params = params, {} if attributes.empty?
      attributes["params"] = params.stringify_keys unless params.empty?

      attributes
    end

    # TODO Comment
    def generate_fake_json_work_item(attributes, participant, workflow_definition_name)
      fake_json_work_item = {
        "dispatch_time" => ActiveSupport::JSON.encode( Time.now ),
        "last_modified" => ActiveSupport::JSON.encode( Time.now ),
        "type" => "OpenWFE::InFlowWorkItem",
        "participant_name" => participant,
        "links" => [],
        "attributes" => attributes.stringify_keys,
        "flow_expression_id" => mock_flow_expression( participant, workflow_definition_name )
      }
      fake_json_work_item
    end

    def mock_flow_expression( participant, workflow_definition_name = nil )
      workflow_definition_name ||= "MockDefinition"

      {
        "workflow_definition_revision" => "0",
        "expression_id" => "0.0.0",
        "engine_id" => "ruote_rest",
        "workflow_definition_url" => "field:__definition",
        "owfe_version" => "0.9.20",
        "workflow_instance_id" => rand(100_000).to_s,
        "workflow_definition_name" => workflow_definition_name,
        "expression_name" => participant
      }
    end

  end
end
