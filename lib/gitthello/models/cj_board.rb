require 'pry'
module Githello
  class CjBoard

    def initialize name
      @name = name
      Trello.configure do |cfg|
        cfg.member_token         = ENV['TRELLO_MEMBER_TOKEN']
        cfg.developer_public_key = ENV['TRELLO_DEV_KEY']
      end
      @board = retrieve_board
    end

    def retrieve_board
      Trello::Board.all.select { |b|
        b.name == @name
      }.first
    end

    def has_card? issue
      all_github_urls.include?(issue['html_url'])
    end

    def all_github_urls
      @all_github_urls ||= @board.lists.map do |a|
        a.cards.map do |card|
          github_details = obtain_github_details(card)
          github_details.nil? ? nil : github_details.url
        end.compact
      end.flatten
    end

    def add_card issue
      $LOG.info "adding issue #{issue['title']} :: #{issue['id']} to trello"
      Trello::Card.create(:name => issue['title'], :list_id => list_id, :desc => issue['body']).tap do |card|
        card.add_attachment(issue['html_url'], "github")
      end
    end

    def add_new_cards_to_repos github
      new_cards.each do |card|
        label = get_github_label(card)
        repo = label.name.split(/:/).last
        owner = 'Clubjudge'
        $LOG.info "adding card #{card.name} to github repo #{repo}"
        begin
          issue = github.issues.create( :user => owner, :repo => repo, :title => card.name, :body => card.desc)
          card.add_attachment(issue['html_url'], "github")
        rescue e
          $LOG.info "Error creating issue for card #{e}"
        end
      end
    end

    def new_cards
      @board.lists.map do |list|
        list.cards.select do |card|
          !is_at_github?(card) && has_github_label?(card)
        end
      end.flatten
    end

    def is_at_github? card
      obtain_github_details(card).present?
    end

    def obtain_github_details card
      card.attachments.select do |a|
        a.name == "github" || a.url =~ /https:\/\/github.com.*issues.*/
      end.first
    end

    def has_github_label? card
      get_github_label(card).present?
    end

    def get_github_label card
      card.labels.select do |a|
        a.name.start_with? "github:"
      end.first
    end

    def list_id
      @list_id ||= @board.lists.select do |list|
        list.name == 'This Sprint'
      end.first.id
    end

  end
end
