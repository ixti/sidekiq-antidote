# frozen_string_literal: true

require "forwardable"
require "strscan"
require "stringio"

module Sidekiq
  module Antidote
    # Job display class pattern matcher. Some job classes may be represented by
    # class and metehod name (e.g., `OnboardingMailer#welcome`) which is handled
    # by this qualifier.
    #
    # ## Pattern Special Characters
    #
    # * `*` matches any number of alpha-numeric characters and underscores.
    #   Examples: `Foo`, `FooBar`, `method_name`
    # * `**` matches any number of components.
    #   Examples: `Foo`, `Foo::Bar`, `Foo::Bar#method_name`
    # * `{A,B,C}` matches literal `A`, `B`, or `C`.
    class ClassQualifier
      extend Forwardable

      LITERAL = %r{(?:[a-z0-9_\#]|::)+}i
      private_constant :LITERAL

      WILDCARD = %r{\*+}
      private_constant :WILDCARD

      ALTERNATION = %r{\{[^*\{]+\}}
      private_constant :ALTERNATION

      # @return [String]
      attr_reader :pattern
      alias to_s pattern

      # @return [Regexp]
      attr_reader :regexp

      # @!method match?(job_class)
      #   @param job_class [String]
      #   @return [Boolean]
      def_delegator :regexp, :match?

      # @param pattern [#to_s]
      def initialize(pattern)
        @pattern = pattern.to_s.strip.freeze
        raise ArgumentError, "blank pattern" if @pattern.empty?

        @regexp = build_regexp(@pattern)

        freeze
      end

      # @param other [Object]
      # @return [Boolean]
      def eql?(other)
        self.class == other.class && pattern == other.pattern
      end
      alias == eql?

      private

      def build_regexp(pattern)
        scanner = StringScanner.new(pattern)
        parts   = StringIO.new

        until scanner.eos?
          next if consume_literal(scanner, parts)
          next if consume_wildcard(scanner, parts)
          next if consume_alternation(scanner, parts)

          raise ArgumentError, "invalid token #{scanner.peek(1)} at #{scanner.pos}: #{scanner.string.inspect}"
        end

        %r{\A#{parts.string}\z}i
      end

      def consume_literal(scanner, parts)
        scanner.scan(LITERAL)&.then { parts << _1 }
      end

      def consume_wildcard(scanner, parts)
        scanner.scan(WILDCARD)&.then do |wildcard|
          case wildcard.length
          when 1 then parts << "[a-z0-9_]*"
          when 2 then parts << "(?:(?:\\#|::)?[a-z0-9_]+)*"
          else
            scanner.unscan
            raise ArgumentError, "ambiguous wildcard #{wildcard} at #{scanner.pos}: #{scanner.string.inspect}"
          end
        end
      end

      def consume_alternation(scanner, parts)
        scanner.scan(ALTERNATION)&.then do |alternation|
          variants = alternation[1...-1].split(",").map { Regexp.escape(_1) }
          parts << "(?:#{variants.join('|')})"
        end
      end
    end
  end
end
