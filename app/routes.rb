require 'sinatra'
require 'mongo'
require 'json'
require 'json/ext'
require 'yaml'
require 'active_support/all'

require_relative '../lib/git_io'

configure do
  environment ||= ENV['RACK_ENV'] || 'development'
  config = YAML.load(ERB.new(File.read('config/database.yml')).result).with_indifferent_access[environment]
  db = Mongo::Client.new(["#{config[:host]}:#{config[:port]}"], { user: config[:user], password: config[:password], database: 'content' })
  set :db, db
end

helpers do
  def guides
    settings.db[:guides]
  end

  def new_id
    IdGenerator.next
  end

  def with_json_body
    yield JSON.parse(request.body.read)
  rescue JSON::ParserError => e
    error 400
  end
end

before do
  content_type 'application/json'
end

get '/guides/:id/raw' do
  guides.find(id: params['id']).projection(_id: 0).to_a.first.to_json
end

get '/guides/:id' do
  guides.find(id: params['id']).projection(_id: 0).map {|it| GitIo::Guide.new(it) }.to_a.first.to_json
end

get '/guides/:organization/:repository/raw' do
  slug = "#{params['organization']}/#{params['repository']}"
  guides.find(github_repository: slug).projection(_id: 0).to_a.first.to_json
end

get '/guides/:organization/:repository' do
  slug = "#{params['organization']}/#{params['repository']}"
  guides.find(github_repository: slug).projection(_id: 0).map {|it| GitIo::Guide.new(it) }.to_a.first.to_json
end

post '/guides' do
  with_json_body do |body|
    id = {id: new_id}
    guides.insert_one body.merge(id)
    id.to_json
  end
end

post '/guides/import/:organization/:name' do
  repo = GitIo::Repo.new(params[:name], params[:organization])
  guide = GitIo::Operation::Import.new(GitIo::Bot.from_env, repo, guides).run!

  guide.to_json
end

put '/guides/:id' do
  with_json_body do |body|
    id = {id: params[:id]}
    guides.update_one id, body
    id.to_json
  end
end