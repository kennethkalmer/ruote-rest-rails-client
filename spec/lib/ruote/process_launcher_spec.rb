require File.dirname(__FILE__) + '/../../spec_helper'

describe Ruote::ProcessLauncher do
  describe "without_processes" do
    it "should correctly manipulate state from enabled to disabled and back again" do
      hosting = Hosting.new

      hosting.processes_enabled.should be_true

      hosting.without_processes do
        hosting.processes_enabled.should be_false
      end

      hosting.processes_enabled.should be_true
    end

    it "should stay disabled after a call" do
      hosting = Hosting.new

      hosting.processes_enabled.should be_true

      Hosting.disable_processes

      hosting.without_processes do
        hosting.processes_enabled.should be_false
      end

      hosting.processes_enabled.should be_false

      Hosting.enable_processes
    end

    it "should handle 'return' statements inside the block" do
      hosting = Hosting.new
      hosting.class_eval <<-EOF
      def foo
        without_processes do
          return false
        end
      end
      EOF

      hosting.processes_enabled.should be_true

      hosting.foo

      hosting.processes_enabled.should be_true
    end
  end
end
