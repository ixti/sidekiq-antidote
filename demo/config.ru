# frozen_string_literal: true

require "bundler/setup"

require "securerandom"

require "sidekiq"
require "sidekiq/web"

require "sidekiq/antidote"
require "sidekiq/antidote/web"

File.open(".session.key", "w") { _1.write(SecureRandom.hex(32)) }
use Rack::Session::Cookie, secret: File.read(".session.key")

map "/" do
  run Sidekiq::Web
end
