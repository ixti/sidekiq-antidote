# frozen_string_literal: true

require_relative "./shared"

module Sidekiq
  module Antidote
    module Middlewares
      class Server
        include Shared
        include Sidekiq::ServerMiddleware

        # @see https://github.com/sidekiq/sidekiq/wiki/Middleware
        # @see https://github.com/sidekiq/sidekiq/wiki/Job-Format
        def call(_, job_payload, _)
          yield unless inhibit(job_payload)
        end
      end
    end
  end
end
