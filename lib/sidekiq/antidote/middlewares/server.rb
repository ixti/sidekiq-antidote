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
        def call(_, job_payload, queue_name)
          yield unless inhibit(job_payload, queue_name)
        end
      end
    end
  end
end
