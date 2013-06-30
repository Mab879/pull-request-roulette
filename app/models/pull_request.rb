class PullRequest < ActiveRecord::Base

  validate :legit?

  def found?
    @pr_data = fetch_pr_data
    return true if @pr_data
    errors[:base] << 'That pull request was not found on Github'
    false
  end

  def self.from_url options
    user, repo, number = self.parse_url options[:url]
    new user: user, repo: repo, number: number, submitter: options[:submitter]
  end

  def known?
    if PullRequest.where(user: user).
                   where(repo: repo).
                   where(number: number).any?
      errors[:base] << 'That pull request is already listed'
      return true
    end
    false
  end

  # do this so the things can be retrieved in the right order
  def legit?
    return false unless url_parsed?
    return false if known?
    return false unless found?
    return false unless open?
    set_author
    set_language
    true
  end

  def open?
    return false unless @pr_data
    return true if @pr_data.state == 'open'
    errors[:base] << "That pull request is not open, it is #{@pr_data.state}"
    false
  end

  def self.parse_url url
    match_data = url_regex.match(url)
    match_data[3..5] if match_data
  end

  def set_author
    self.author = @pr_data.user.login
  end

  def set_language
    self.language = fetch_repo_languages.to_json.to_s
  end

  def to_url
    self.class.url_format % [user, repo, number]
  end

  def self.url_format
    'https://github.com/%s/%s/pull/%d'
  end

  def url_parsed?
    return true if user && repo && number
    errors[:base] << 'That is not a valid Github pull request URL'
    false
  end

  def self.url_regex
    /(https?:\/\/)?(www\.)?github.com\/(.*)\/(.*)\/pull\/([0-9]+)\z/
  end

  private

  def github
    Github.new client_id: ENV['GITHUB_KEY'], client_secret: ENV['GITHUB_SECRET']
  end

  def fetch_pr_data
    begin
      github.pull_requests.find(user, repo, number)
    rescue ArgumentError, Github::Error::NotFound, URI::InvalidURIError
      nil
    end
  end
  
  def fetch_repo_languages
    github.repos.languages(user, repo)
  end

end
