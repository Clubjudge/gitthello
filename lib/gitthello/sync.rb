module Gitthello
  class Sync
    def initialize
      $LOG ||= Logger.new(logfile)
      @developers_board = Githello::CjBoard.new 'Development Team'
      @product_board = Githello::CjBoard.new 'Product Backlog'
      @repos = ENV['REPOS'].split(/,/)
      @github = Github.new(:oauth_token => ENV['GITHUB_ACCESS_TOKEN'])
      @issues_bucket = []
      @cards_bucket = []
    end

    def synchronize
      $LOG.info "starting sync"
      $LOG.info "getting new issues"
      get_new_issues
      $LOG.info "adding new issues to trello"
      add_issues_to_boards
      $LOG.info "adding new cards to github"
      add_cards_to_repos
      $LOG.info "ending sync"
    end

    def get_new_issues
      @issues_bucket = @repos.map do |repo|
        repo.split(/\//)
      end.map do |owner, name|
        $LOG.info "#{owner}/#{name}"
        @github.issues.list(:user => owner, :repo => name, :state => "open").sort_by { |a| a.number.to_i }
      end.flatten
    end

    def add_cards_to_repos
      @developers_board.add_new_cards_to_repos @github
      @product_board.add_new_cards_to_repos @github
    end

    def add_issues_to_boards
      @issues_bucket.each do |issue|
        unless issue_added? issue
          @developers_board.add_card issue
        end
      end
    end

    def issue_added? issue
      @product_board.has_card?(issue) || @developers_board.has_card?(issue)
    end

    def logfile
      ENV['LOGFILE'] || './log/sync.log'
    end

  end
end
