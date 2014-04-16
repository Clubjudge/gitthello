desc "Synchronize Github and Trello"
task :sync do
  Gitthello::Sync.new.synchronize
end

desc "Link issues to cards if the issue don't already have a link."
task :link_issues_to_cards do
  Gitthello::Sync.new.add_trello_link_to_issues
end

desc "Synchronize specific board given by name."
task :sync_board, :name do |t,args|
  Gitthello::Sync.new.synchronize_only_board(args.name)
end
