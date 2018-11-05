require 'sinatra'
require 'mumukit/content_type'

require 'sinatra/cross_origin'
require 'logger'
require 'mumukit/auth'

require 'json'
require 'yaml'

configure do
  enable :cross_origin
  set :allow_methods, [:get, :put, :post, :options, :delete]
  set :show_exceptions, false

  set :app_name, 'bibliotheca'
  set :static, true
  set :public_folder, 'public'

  use ::Rack::CommonLogger, Rails.logger
end

helpers do
  def json_body
    @json_body ||= JSON.parse(request.body.read) rescue nil
  end

  def slug
    if route_slug_parts.present?
      Mumukit::Auth::Slug.join(*route_slug_parts)
    elsif subject
      Mumukit::Auth::Slug.parse(subject.slug)
    elsif json_body
      Mumukit::Auth::Slug.parse(json_body['slug'])
    else
      raise Mumukit::Auth::InvalidSlugFormatError.new('Slug not available')
    end
  end

  def route_slug_parts
    []
  end
end

before do
  content_type 'application/json', 'charset' => 'utf-8'
end

after do
  error_message = env['sinatra.error']
  if response.body.is_a?(Array)&& response.body[0].is_a?(String)
    if content_type != 'application/csv'
      content_type 'text/html'
      response.body[0] = <<HTML
    <html>
      <body>
        #{response.body[0]}
      </body>
    </html>
HTML
    end
    response.body = response.body[0]
  elsif error_message.blank?
    response.body = response.body.to_json
  else
    response.body = {message: env['sinatra.error'].message}.to_json
  end
end

error JSON::ParserError do
  halt 400
end

error Mumukit::Auth::InvalidTokenError do
  halt 401
end

error Mumukit::Auth::UnauthorizedAccessError do
  halt 403
end

error ActiveRecord::RecordInvalid do
  halt 400
end

error Mumukit::Auth::InvalidSlugFormatError do
  halt 400
end

error ActiveRecord::RecordNotFound do
  halt 404
end

options '*' do
  response.headers['Allow'] = settings.allow_methods.map { |it| it.to_s.upcase }.join(',')
  response.headers['Access-Control-Allow-Headers'] = 'X-Mumuki-Auth-Token, X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept, Authorization'
  200
end

helpers do
  Mumukit::Login.configure_controller! self
end

before do
  I18n.locale = 'en' #TODO: Remove hardcoded locale
end

helpers do
  def authenticate!
    halt 401 unless current_user?
  end

  def authorization_slug
    slug
  end

  def bot
    Mumukit::Sync::Store::Github::Bot.from_env
  end

  def subject
    Guide.find_by_id(params[:id])
  end

  def route_slug_parts
    [params[:organization], params[:repository]].compact
  end

  def history_syncer
    Mumuki::Bibliotheca.history_syncer(bot, current_user&.email)
  end

  def upsert!(content_kind)
    authorize! :writer
    content = Mumuki::Bibliotheca.api_syncer(json_body).locate_and_import! content_kind, slug.to_s
    history_syncer.export! content
    content.to_resource_h
  end

  def fork!(collection_class)
    authorize! :writer
    destination = json_body['organization']
    collection_class.find_by_slug!(slug.to_s).fork_to!(destination, history_syncer).as_json
  end

  def delete!(collection_class)
    authorize! :editor
    collection_class.find_by_slug!(slug.to_s).destroy!
    {}
  end
end

post '/markdown' do
  {markdown: Mumukit::ContentType::Markdown.to_html(json_body['markdown'])}
end

post '/markdowns' do
  json_body.with_indifferent_access.tap do |guide|
    guide[:exercises].each do |exercise|
      exercise[:description] = Mumukit::ContentType::Markdown.to_html(exercise[:description])
    end
  end
end

get '/permissions' do
  authenticate!

  {permissions: current_user.permissions}
end


require_relative './sinatra/organization'
require_relative './sinatra/languages'
require_relative './sinatra/guides'
require_relative './sinatra/books'
require_relative './sinatra/topics'