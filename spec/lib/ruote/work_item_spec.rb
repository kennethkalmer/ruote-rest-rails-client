require File.dirname(__FILE__) + '/../../spec_helper'

describe Ruote::WorkItem do

  describe "Rails and ruote-rest routing compatibility" do
    it "should encode the id correctly" do
      Ruote::WorkItem.encode_url_id( '20081225-christmas', '0.0.0' ).should == "20081225-christmas/0_0_0"
    end

    it "should encode/escape the id correctly" do
      Ruote::WorkItem.encode_url_id( '20081225-christmas', '0.0.0', true ).should == "20081225-christmas%2F0_0_0"
    end

    it "should decode the id correctly" do
      %w{ 20081225-christmas%2F0_0_0 20081225-christmas%2F0.0.0
      20081225-christmas/0.0.0 20081225-christmas/0_0_0 }.each do |id|
        Ruote::WorkItem.decode_url_id( id ).should == '20081225-christmas/0.0.0'
      end
    end

    it "should decode and keep underscore in expression_id if asked" do
      %w{ 20081225-christmas%2F0_0_0 20081225-christmas%2F0.0.0
      20081225-christmas/0.0.0 20081225-christmas/0_0_0 }.each do |id|
        Ruote::WorkItem.decode_url_id( id, true ).should == '20081225-christmas/0_0_0'
      end
    end
  end
end
