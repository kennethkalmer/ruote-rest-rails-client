class JobsController < ApplicationController

  rescue_from Errno::ECONNREFUSED, :with => :ruote_missing

  def index
    # Example of how to map local users into ruote participants, either by roles
    # or by name directly
    if current_login.is_a?( Broker )
      @workitems = []
      current_login.login_roles.each do |role|
        next if role.to_s == 'admin'
        @workitems.concat( Ruote::WorkItem.find( :all, :participant => role.to_s.dasherize ) )
      end
    else
      @workitems = Ruote::WorkItem.find( :all, :participant => current_login )
    end
  end

  def show
    @workitem = Ruote::WorkItem.find( params[:id] )

    begin
      @model = @workitem.model
    rescue ActiveRecord::RecordNotFound
      # Don't worry about this one...
    end

    if @model.nil?
      render :action => 'model_missing'
      return
    end
    
    render :action => @workitem.name.underscore
  end

  def update
    @workitem = Ruote::WorkItem.find( params[:id] )

    # Workitem attributes
    unless params[:attributes].blank?
      params[:attributes].each_pair do |key, value|
        if @workitem[key] && @workitem[key].is_a?( Hash )
          @workitem[key].merge!( value )
        else
          @workitem[key] = value
        end
      end
    end

    # Model attributes
    unless params[:model].blank?
      @model = @workitem.model rescue nil
      if @model
        @model.without_processes do
          if @model.update_attributes( params[:model] )

            # Update the attributes if needed
            @workitem.attributes.merge!( @model.ruote_payload )
          else
            render :action => @workitem.name.underscore
            return false
          end
        end
      end
    end
    
    if params[:commit] && params[:commit].downcase =~ /cancel/
      flash[:error] = "Process terminated"
      @workitem.cancel_process!
    else
      flash[:info] = "Activity processed"
      @workitem.proceed!
    end
    
    redirect_to jobs_path
  end

  def visualize
    @workitem = Ruote::WorkItem.find( params[:id] )
  end

  protected

  def ruote_missing
    respond_to do |format|
      format.html { render :action => 'ruote_missing' }
    end
  end
  
end
