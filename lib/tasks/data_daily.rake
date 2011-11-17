namespace :data do
  task :daily => :environment do
    Content::ImportDriver::EntryDriver.new.perform
  end
  
  namespace :daily do 
    task :basic => %w(
      content:entries:import
      content:entries:import:graphics
      data:extract:places
    )
    
    task :quick => %w(
      data:daily:basic
      content:issues:mark_complete
    )
    task :catch_up => %w(
      data:daily:basic
      content:entries:html:compile:all
      content:issues:mark_complete
    )
    
    task :full => %w(
      content:section_highlights:clone
      data:daily:basic
      content:entries:html:compile:all
      remote:sphinx:rebuild_delta
      content:issues:mark_complete
      content:public_inspection:reindex
      varnish:expire:everything
      mailing_lists:entries:deliver
      sitemap:refresh
    )
    # content:entries:import:regulations_dot_gov:tardy
  end
end
