module Gitthello
  class Sync
    def initialize
      @developers_board = Githello::CjBoard.new 'Development Team'
      @product_board = Githello::CjBoard.new 'Product Backlog'
      @repos = ENV['REPOS'].split(/,/)
      @github = Github.new(:oauth_token => ENV['GITHUB_ACCESS_TOKEN'])
      @issues_bucket = []
      @cards_bucket = []
    end

    def synchronize
      p "getting new issues"
      get_new_issues
      p "adding new issues to trello"
      add_issues_to_boards
      p "adding new cards to github"
      add_cards_to_repos
    end

    def get_new_issues
      @issues_bucket = @repos.map do |repo|
        repo.split(/\//)
      end.map do |owner, name|
        p "#{owner}/#{name}"
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

    def synchronize_only_board(board_name)
      # because the trello API is a bit flaky, brute-force retry this
      # if API throws an error.
      repeatthis do
        @boards.select { |a|
          a.name == board_name
        }.map(&:synchronize)
      end
    end

    def add_trello_link_to_issues
      @boards.map(&:add_trello_link_to_issues)
    end

    def archive_done_in_board(board_name)
      repeatthis do
        @boards.
          select { |a| a.name == board_name }.
          map(&:trello_helper).
          map(&:setup).
          map(&:archive_done)
      end
    end

    private

    def repeatthis(cnt=5,&block)
      last_exception = nil
      cnt.times do
        begin
          return yield
        rescue Exception => e
          last_exception = e
          sleep 0.1
          next
        end
      end
      raise last_exception
    end

  end
end
