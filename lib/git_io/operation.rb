class GitIo::Operation
  include GitIo::WithFileReading

  attr_accessor :repo

  def with_cloned_repo
    Dir.mktmpdir("mumuki.#{id}.#{self.class.name}") do |dir|
      repo = committer.clone_repo_into guide, dir
      yield dir, repo
    end
  end

end


require_relative './operation/export'
require_relative './operation/import'
require_relative './operation/import_log'
