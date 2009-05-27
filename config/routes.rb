ActionController::Routing::Routes.draw do |map|

  # Jobs that don't seem to work with resources
  map.jobs '/jobs', :controller => 'jobs', :action => 'index'
  map.show_job '/job/s/:id', :controller => 'jobs', :action => 'show'
  map.process_job '/job/p/:id', :controller => 'jobs', :action => 'update'
  map.visualize_job '/job/v/:id', :controller => 'jobs', :action => 'visualize'

end
