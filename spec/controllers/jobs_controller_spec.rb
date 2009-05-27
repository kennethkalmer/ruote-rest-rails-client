require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe JobsController do

  before(:each) do
    rescue_action_in_public!
  end

  it "should route id's with slashed in" do
    id = '20081225-christmas/0_0_0'
    escaped_id = Ruote::WorkItem.encode_url_id('20081225-christmas', '0.0.0', true)

    params_from(:get, '/job/s/' + escaped_id).should == {
      :controller => 'jobs', :action => 'show', :id => id
    }

    params_from(:get, '/job/p/' + escaped_id).should == {
      :controller => 'jobs', :action => 'update', :id => id
    }
  end

  it "should generate routes correctly" do
    pending "WTF"
    item = mock_work_item('insurance')

    get :index

    jobs_path.should == "/jobs"
    show_job_path(:id => item.to_param, :escape => false).should == "/job/s/#{item.to_param}"
    process_job_path(:id => item, :escape => false).should == "/job/p/#{item.to_param}"
  end

  it "should handle ruote-rest not running" do
    @request.remote_addr = '1.2.3.4'
    @request.host = 'example.com'
    Ruote::WorkItem.stubs(:find).with(any_parameters).raises(Errno::ECONNREFUSED)

    @broker = Factory(:broker, :roles => ['insurance'])
    login_as( @broker )

    get :index

    response.should render_template('jobs/ruote_missing')
  end

  describe "for admins" do
    before(:each) do
      @broker = Factory(:broker, :roles => ['insurance'])
      login_as( @broker )

      @service = Factory( :insurance, :broker => @broker, :client => Factory(:client) )
    end

    it "should have a list of workitems" do
      item = mock_work_item(
        'insurance',
        "ServiceProcess",
        @service,
        { :type => 'Insurance', :number => 'I00001' }
      )
      stub_find_by_participant( 'insurance', item )

      get :index

      assigns[:workitems].should include(item)

      response.should render_template('jobs/index')
    end

    describe "should have a view of a" do
      it "insurance" do
        item = mock_work_item(
          'insurance',
          "ServiceProcess",
          @service,
          { :type => 'Insurance', :number => 'I00001' }
        )
        stub_find_wi_by_id( item )

        get :show, :id => item.to_param

        assigns[:workitem].should == item
        assigns[:model].should == @service

        response.should render_template('jobs/service_process')
      end

      it "missing insurance" do
        item = mock_work_item(
          'insurance',
          'ServiceProcess',
          @service,
          { :type => 'Insurance', :number => 'I00002' }
        )
        Ruote::WorkItem.any_instance.expects(:model).raises(ActiveRecord::RecordNotFound)
        stub_find_wi_by_id( item )

        get :show, :id => item.to_param

        assigns[:workitem].should == item
        assigns[:model].should be_nil

        response.should render_template('jobs/model_missing')
      end

      it "nil insurance" do
        item = mock_work_item(
          'insurance',
          'ServiceProcess',
          @service,
          { :type => 'Insurance', :number => 'I00001' }
        )
        Ruote::WorkItem.any_instance.expects(:model).returns(nil)
        stub_find_wi_by_id( item )

        get :show, :id => item.to_param

        assigns[:workitem].should == item
        assigns[:model].should be_nil

        response.should render_template('jobs/model_missing')
      end

    end

    it "should update workitem attributes" do
      item = mock_work_item(
        'insurance',
        "ServiceProcess",
        @service,
        { :type => 'Insurance', :number => 'I00001' }
      )
      stub_find_wi_by_id( item )

      put :update, :id => item.to_param, :attributes => { :number => '123456' }

      assigns[:workitem][:number].should == '123456'

      flash[:info].should_not be_nil
      response.should be_redirect
      response.should redirect_to( jobs_path )
    end

    it "should merge hashes in workitem attributes" do
      item = mock_work_item(
        'insurance',
        "ServiceProcess",
        @service,
        { :type => 'Insurance', :number => 'I00001' }
      )
      stub_find_wi_by_id( item )

      put :update, :id => item.to_param, :attributes => { :policy => { :foo => 'bar' } }

      assigns[:workitem][:policy]['foo'].should == 'bar'
    end

    it "should update an associated model" do
      @service.update_attributes :transfer => true, :to => 'AIG'
      item = mock_work_item(
        'insurance',
        "TransferInternationalDomain",
        @service,
        { :type => 'Insurance', :number => 'I00001' }
      )
      stub_find_wi_by_id( item )

      put :update, :id => item.to_param, :model => { :code => 'zW3dvb7edZ' }

      @service.reload.code.should == 'zW3dvb7edZ'
      assigns[:workitem]['service']['code'].should == 'zW3dvb7edZ'

      flash[:info].should_not be_nil
      response.should be_redirect
      response.should redirect_to( jobs_path )
    end

    it "should cancel a process" do
      item = mock_work_item(
        'insurance',
        "ServiceProcess",
        @service,
        { :type => 'Insurance', :number => 'I00001' }
      )
      stub_find_wi_by_id( item )

      put :update, :id => item.to_param, :commit => "Cancel this process"

      flash[:info].should be_nil
      flash[:error].should_not be_nil

      response.should be_redirect
      response.should redirect_to( jobs_path )
    end
  end
end
