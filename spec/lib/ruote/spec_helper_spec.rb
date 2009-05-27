require File.dirname(__FILE__) + '/../../spec_helper'

describe Ruote::SpecHelper do

  describe "mock_work_item" do

    it "should require a participant name" do
      lambda {
        mock_work_item
      }.should raise_error( ArgumentError, "Participant object expected as first argument" )
    end

    it "should generate the correct participant name" do
      wi = mock_work_item( 'dialup_admin' )
      wi.participant_name.should == 'dialup-admin'

      isp = Factory(:active_isp)
      wi = mock_work_item( isp )
      wi.participant_name.should == "isp-#{isp.id}"
    end

    it "should set a default process name" do
      wi = mock_work_item( 'dialup_admin' )
      wi.name.should == 'MockDefinition'
    end

    it "should set the provided process name" do
      wi = mock_work_item( 'dialup_admin', 'SpecHelperSpec' )
      wi.name.should == 'SpecHelperSpec'
    end

    it "should set the model" do
      model = Factory( :domain, :owner => Factory(:active_isp) )
      wi = mock_work_item( 'dialup_admin', model )
      
      wi.model.should == model
    end
  end

  describe "extract_params_and_attributes" do
    it "should extract attributes from args" do
      args = [ {:foo => :bar} ]
      attributes = extract_params_and_attributes(args)

      attributes.should == { :foo => :bar }

      args.should be_empty
    end

    it "should extract attributes and params from args" do
      args = [ {:foo => :bar}, {:ba => :ramba} ]
      attributes = extract_params_and_attributes(args)

      attributes.should == { :foo => :bar, "params" => { "ba" => :ramba } }

      args.should be_empty
    end
  end

  describe "extract_workflow_definition_and_model" do
    it "should extract a model from arguments with process name" do
      model = Factory( :domain, :owner => Factory(:active_isp) )
      args = [ 'Process', model ]

      wf, m = extract_workflow_definition_and_model( args )

      wf.should == 'Process'
      m.should == model
    end

    it "should extract a model from arguments without process name" do
      model = Factory( :domain, :owner => Factory(:active_isp) )
      args = [ model ]

      wf, m = extract_workflow_definition_and_model( args )

      wf.should be_nil
      m.should == model
    end
  end
end
