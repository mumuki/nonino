helpers do
  def list_guides(guides)
    { guides: guides.as_json(only: [:name, :slug, :type, :language]) }
  end
end

get '/guides' do
  list_guides Guide.visible(current_user&.permissions)
end

get '/guides/writable' do
  list_guides Guide.allowed(current_user&.permissions)
end

get '/guides/:organization/:repository/markdown' do
  Guide.find_by_slug!(slug.to_s).to_markdownified_resource_h
end

get '/guides/:organization/:repository' do
  Guide.find_by_slug!(slug.to_s).to_resource_h
end

post '/guides' do
  upsert! :guide
end

post '/guides/import/:organization/:repository' do
  Mumuki::Bibliotheca.history_syncer(bot).import! Guide.find_by_slug!(slug.to_s)
end

post '/guides/:organization/:repository/assets' do
  bot.upload_asset!(slug, json_body['filename'], Base64.decode64(json_body['content'])).as_json
end

post '/guides/:organization/:repository/fork' do
  fork! Guide
end

# <b>DEPRECATED:</b> Please use <tt>/assets</tt> instead of /images.
post '/guides/:organization/:repository/images' do
  bot.upload_asset!(slug, json_body['filename'], Base64.decode64(json_body['content'])).as_json
end
