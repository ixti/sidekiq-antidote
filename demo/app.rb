# frozen_string_literal: true

require "bundler/setup"

require "sidekiq"
require "sidekiq/antidote"

module AntidoteDemo
  class FirstJob
    include Sidekiq::Job

    def perform(num)
      puts "performing #{num}..."
      sleep 1
    end
  end

  class SecondJob
    include Sidekiq::Job

    def perform(num)
      puts "performing #{num}..."
      sleep 1
    end
  end
end
