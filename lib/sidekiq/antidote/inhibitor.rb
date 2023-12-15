# frozen_string_literal: true

require "securerandom"

require_relative "./class_qualifier"

module Sidekiq
  module Antidote
    # Single poison inhibition rule: class qualifier + treatment action.
    class Inhibitor
      TREATMENTS  = %w[skip kill suspend].freeze

      # @return [String]
      attr_reader :id

      # @return ["skip", "kill", "suspend"]
      attr_reader :treatment

      # @return [ClassQualifier]
      attr_reader :class_qualifier

      # @param id [#to_s]
      # @param treatment ["skip", "kill", "suspend"]
      # @param class_qualifier [#to_s]
      def initialize(id:, treatment:, class_qualifier:)
        @id              = -id.to_s
        @treatment       = -treatment.to_s
        @class_qualifier = ClassQualifier.new(class_qualifier.to_s)

        raise ArgumentError, "invalid id: #{id.inspect}"               if @id.empty?
        raise ArgumentError, "invalid treatment: #{treatment.inspect}" unless TREATMENTS.include?(@treatment)

        freeze
      end

      def match?(job_record)
        class_qualifier.match?(job_record.display_class)
      end

      def to_s
        "#{treatment} #{class_qualifier}"
      end

      def eql?(other)
        self.class == other.class \
          && id == other.id && treatment == other.treatment && class_qualifier == other.class_qualifier
      end
      alias == eql?
    end
  end
end
