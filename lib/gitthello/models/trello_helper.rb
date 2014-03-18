module Gitthello
  class TrelloHelper
    attr_reader :list_todo, :list_backlog, :list_done, :github_urls, :board

    def initialize(token, dev_key, board_name)
      Trello.configure do |cfg|
        cfg.member_token         = token
        cfg.developer_public_key = dev_key
      end
      @board_name = board_name
    end

    def setup
      @board = retrieve_board

      @list_todo    = @board.lists.select { |a| a.name == 'To Do' }.first
      raise "Missing trello To Do list" if list_todo.nil?

      @list_backlog = @board.lists.select { |a| a.name == 'Backlog' }.first
      raise "Missing trello Backlog list" if list_backlog.nil?

      @list_done    = @board.lists.select { |a| a.name == 'Done' }.first
      raise "Missing trello Done list" if list_done.nil?

      @github_urls = all_github_urls
      puts "Found #{@github_urls.count} github urls"
    end

    def has_card?(issue)
      @github_urls.include?(issue["html_url"])
    end

    def create_todo_card(name, desc, issue_url)
      create_card_in_list(name, desc, issue_url, list_todo.id)
    end

    def create_backlog_card(name, desc, issue_url)
      create_card_in_list(name, desc, issue_url, list_backlog.id)
    end

    #
    # Close github issues that have been moved to the done list
    #
    def close_issues(github_helper)
      list_done.cards.each do |card|
        github_details = card.attachments.select{ |a| a.name == "github"}.first
        next if github_details.nil?
        user,repo,_,number = github_details.url.split(/\//)[3..-1]
        github_helper.close_issue(user,repo,number)
      end
    end

    def move_cards_with_closed_issue(github_helper)
      board.lists.each do |list|
        next if list.id == list_done.id
        list.cards.each do |card|
          d = obtain_github_details(card)
          next if d.nil?
          user,repo,_,number = d.url.split(/\//)[3..-1]
          if github_helper.issue_closed?(user,repo,number)
            card.move_to_list(list_done)
          end
        end
      end
    end

    def new_cards_to_github(github_helper)
      all_cards_not_at_github.each do |card|
        issue = github_helper.
          create_issue(card.name,
                       card.desc + "\n\n\n[Added by trello](#{card.url})")
        card.add_attachment(issue.html_url, "github")
      end
    end

    private

    def create_card_in_list(name, desc, url, list_id)
      Trello::Card.
        create( :name => name, :list_id => list_id, :desc => desc).
        add_attachment(url, "github")
    end

    def obtain_github_details(card)
      card.attachments.select{ |a| a.name == "github"}.first
    end

    def retrieve_board
      Trello::Board.all.
        select { |b| b.name == @board_name }.first
    end

    def all_cards_not_at_github
      board.lists.map do |a|
        a.cards.map do |card|
          obtain_github_details(card).nil? ? card : nil
        end.compact
      end.flatten.reject do |card|
        # ignore new cards in the Done list - for these we don't
        # need to create github issues
        card.list_id == list_done.id
      end
    end

    def all_github_urls
      board.lists.map do |a|
        a.cards.map do |card|
          github_details = obtain_github_details(card)
          github_details.nil? ? nil : github_details.url
        end.compact
      end.flatten
    end
  end
end
