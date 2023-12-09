# frozen_string_literal: true

require_relative "./inhibitor"

module Sidekiq
  module Antidote
    # Inhibitors repository
    class Repository
      include Enumerable

      REDIS_KEY = "sidekiq-antidote"

      # @overload each
      #   @return [Enumerator<Inhibitor>]
      #
      # @overload each(&block)
      #   For a block { |inhibitor| ... }
      #   @yieldparam inhibitor [Inhibitor]
      #   @return [self]
      def each
        return to_enum __method__ unless block_given?

        broken_ids = []

        redis("HGETALL", REDIS_KEY).each do |id, payload|
          inhibitor = deserialize(id, payload)
          next yield inhibitor if inhibitor

          broken_ids << id
        end

        delete(*broken_ids)
        self
      end

      # @param treatment (see Inhibitor#initialize)
      # @param class_qualifier (see Inhibitor#initialize)
      # @raise [RuntimeError] when can't generate new inhibitor ID
      # @return [Inhibitor]
      def add(treatment:, class_qualifier:)
        3.times do
          inhibitor = Sidekiq::Antidote::Inhibitor.new(
            id:              SecureRandom.hex(8),
            treatment:       treatment,
            class_qualifier: class_qualifier
          )

          return inhibitor if redis("HSETNX", REDIS_KEY, *serialize(inhibitor)).to_i.positive?
        end

        raise "can't generate available ID"
      end

      # @param ids [Array<String>]
      # @return [nil]
      def delete(*ids)
        redis("HDEL", REDIS_KEY, *ids) unless ids.empty?
        nil
      end

      private

      def deserialize(id, payload)
        treatment, class_qualifier = Sidekiq.load_json(payload)

        Inhibitor.new(id: id, treatment: treatment, class_qualifier: class_qualifier)
      rescue StandardError => e
        Antidote.log(:error) { "failed deserializing inhibitor (#{payload.inspect}): #{e.message}" }
        nil
      end

      def serialize(inhibitor)
        [
          inhibitor.id,
          Sidekiq.dump_json([
            inhibitor.treatment,
            inhibitor.class_qualifier.pattern
          ])
        ]
      end

      def redis(...)
        Sidekiq.redis { _1.call(...) }
      end
    end
  end
end
