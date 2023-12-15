# frozen_string_literal: true

module Sidekiq
  module Antidote
    # Suspension groups for suspend treatment
    class SuspensionGroup
      include Enumerable

      def self.all
        redis("KEYS", "#{Repository::REDIS_KEY}:suspend:*").to_a.map do |sg|
          name = sg.split(":").last

          SuspensionGroup.new(name: name)
        end
      end

      def self.redis(...)
        Sidekiq.redis { _1.call(...) }
      end

      # @return [String]
      attr_reader :name

      def initialize(name:)
        @name = name.to_s
        @rname = "#{Repository::REDIS_KEY}:suspend:#{name}"
      end

      def size
        @size ||= self.class.redis("LLEN", @rname)
      end

      def each(&block)
        page = 0
        page_size = 50

        loop do
          range_start = page * page_size
          range_end = range_start + page_size - 1
          entries = self.class.redis("LRANGE", @rname, range_start, range_end)

          break if entries.empty?

          page += 1
          entries.each(&block)
        end
      end

      def add(message:)
        self.class.redis("LPUSH", @rname, Sidekiq.dump_json(message))
      end
    end
  end
end
