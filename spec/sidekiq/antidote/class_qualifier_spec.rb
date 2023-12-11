# frozen_string_literal: true

RSpec.describe Sidekiq::Antidote::ClassQualifier do
  subject(:qualifier) { described_class.new(pattern) }

  let(:pattern) { "A::*::**::C#xyz" }

  describe ".new" do
    it { is_expected.to be_an_instance_of(described_class).and(be_frozen) }

    where(pattern: ["", nil])
    with_them do
      it "fails initialization" do
        expect { qualifier }.to raise_error(ArgumentError, "blank pattern")
      end
    end

    context "when pattern has unexpected tokens" do
      let(:pattern) { "A::^-^::C" }

      it "fails initialization" do
        expect { qualifier }.to raise_error(ArgumentError, 'invalid token ^ at 3: "A::^-^::C"')
      end
    end

    context "when pattern has ambiguous wildcard tokens" do
      let(:pattern) { "A::***::C" }

      it "fails initialization" do
        expect { qualifier }.to raise_error(ArgumentError, 'ambiguous wildcard *** at 3: "A::***::C"')
      end
    end

    context "when pattern has invalid alternation tokens" do
      let(:pattern) { "A::{*}::C" }

      it "fails initialization" do
        expect { qualifier }.to raise_error(ArgumentError, 'invalid token { at 3: "A::{*}::C"')
      end
    end
  end

  describe "#pattern" do
    subject { qualifier.pattern }

    it { is_expected.to be_frozen }
    it { is_expected.to eq(pattern) }
  end

  describe "#to_s" do
    it "is an alias of #pattern" do
      expect(qualifier.method(:to_s)).to eq(qualifier.method(:pattern))
    end
  end

  describe "#regexp" do
    subject { qualifier.regexp }

    it { is_expected.to eq(%r{\AA::[a-z0-9_]*::(?:(?:\#|::)?[a-z0-9_]+)*::C#xyz\z}i) }
  end

  describe "#match?" do
    shared_examples "pattern matching" do |pattern:, works_for:, fails_for: []|
      context "when pattern is <#{pattern}>" do
        let(:qualifier) { described_class.new(pattern) }

        works_for.each do |job_class|
          it "returns <true> for <#{job_class}>" do
            expect(qualifier.match?(job_class)).to be true
          end
        end

        fails_for.each do |job_class|
          it "returns <false> for <#{job_class}>" do
            expect(qualifier.match?(job_class)).to be false
          end
        end
      end
    end

    include_examples "pattern matching",
      pattern:   "A::B::C",
      works_for: %w[A::B::C],
      fails_for: %w[A::B::C::D A::B::CJob A::B::C#method_name]

    include_examples "pattern matching",
      pattern:   "A::*::C",
      works_for: %w[A::::C A::B::C A::X::C],
      fails_for: %w[A::*::C A::B::C::D A::B::CJob A::B::C#method_name]

    include_examples "pattern matching",
      pattern:   "A::B::*",
      works_for: %w[A::B:: A::B::C A::B::CJob],
      fails_for: %w[A::B::* A::B::C::D A::B::C#method_name]

    include_examples "pattern matching",
      pattern:   "A::B::*Job#method_name",
      works_for: %w[A::B::Job#method_name A::B::CJob#method_name],
      fails_for: %w[A::B::*Job#method_name A::B::C::DreamJob#method_name]

    include_examples "pattern matching",
      pattern:   "A::**::C",
      works_for: %w[A::::C A::B::C A::B::B::C],
      fails_for: %w[A::**::C A::B::C::D A::B::C#method_name]

    include_examples "pattern matching",
      pattern:   "A::B::**",
      works_for: %w[A::B:: A::B::C A::B::CJob A::B::C::D A::B::C#method_name],
      fails_for: %w[A::B::**]

    include_examples "pattern matching",
      pattern:   "A**::Job",
      works_for: %w[A::Job A::B::Job],
      fails_for: %w[A**::Job]

    include_examples "pattern matching",
      pattern:   "A::{B,C}::{D}::E",
      works_for: %w[A::B::D::E A::C::D::E],
      fails_for: %w[A::B::D A::B,C::D::E]

    include_examples "pattern matching",
      pattern:   "*",
      works_for: %w[A],
      fails_for: %w[A::B A#method_name]

    include_examples "pattern matching",
      pattern:   "**",
      works_for: %w[A A::B A::B::C A#method_name A::B#method_name]
  end

  describe "#eql?" do
    subject { qualifier == other_qualifier }

    let(:other_pattern)   { qualifier.pattern }
    let(:other_qualifier) { described_class.new(other_pattern) }

    it { is_expected.to be true }

    context "when pattern mismatch" do
      let(:other_pattern) { "Other::#{pattern}" }

      it { is_expected.to be false }
    end
  end

  describe "#==" do
    it "is an alias of #eql?" do
      expect(qualifier.method(:==)).to eq qualifier.method(:eql?)
    end
  end
end
