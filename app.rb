require 'sinatra'
require 'mysql2'
require 'cgi'
#require 'json-schema'
require 'gems'
require 'concurrent-ruby'
require_relative '_info'
require_relative '_include'

set :public_folder, 'assets'

def f1
  $out = ""
  $params = params
  #load "_include.rb"
  load params[:file_name] + ".rb"
  $out
end
post '/dev/:file_name' do
  f1
end
get '/dev/:file_name' do
  f1
end

# 透明gifをファビコンとして返す
get '/favicon.ico' do
  content_type 'image/x-icon'
  "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\xdac\xf8\xff\xff?\x00\x05\xfe\x02\xfe\xa7\xd6\x92\xd2\x00\x00\x00\x00IEND\xaeB`\x82"
end