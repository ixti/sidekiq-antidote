# frozen_string_literal: true

RSpec.describe Sidekiq::Antidote::Inhibitor do
  subject(:inhibitor) do
    described_class.new(id: id, treatment: treatment, class_qualifier: class_qualifier)
  end

  let(:id)              { +"deadbeef" }
  let(:treatment)       { +"skip" }
  let(:class_qualifier) { +"DreamJob" }

  describe ".new" do
    it { is_expected.to be_an_instance_of(described_class).and(be_frozen) }

    where(treatment: ["skip", "kill", :skip, :kill])
    with_them do
      it { is_expected.to be_an_instance_of(described_class) }
      it { is_expected.to have_attributes(id: id.to_s) }
      it { is_expected.to have_attributes(treatment: treatment.to_s) }
      it { is_expected.to have_attributes(class_qualifier: Sidekiq::Antidote::ClassQualifier.new(class_qualifier)) }
    end

    context "with invalid id" do
      where(id: [nil, ""])
      with_them do
        it "fails intialization" do
          expect { inhibitor }.to raise_error(ArgumentError, "invalid id: #{id.inspect}")
        end
      end
    end

    context "with invalid treatment" do
      where(treatment: [nil, "", "noop"])
      with_them do
        it "fails intialization" do
          expect { inhibitor }.to raise_error(ArgumentError, "invalid treatment: #{treatment.inspect}")
        end
      end
    end

    context "with invalid class qualifier" do
      where(class_qualifier: [nil, ""])
      with_them do
        it "fails intialization because of blank patttern" do
          expect { inhibitor }.to raise_error(ArgumentError, "blank pattern")
        end
      end

      where(class_qualifier: ["Invalid!Qualifier"])
      with_them do
        it "fails intialization because of invalid token" do
          expect { inhibitor }.to raise_error(ArgumentError, %r{invalid token})
        end
      end

      where(class_qualifier: ["***Job"])
      with_them do
        it "fails intialization because of ambiguous wildcard" do
          expect { inhibitor }.to raise_error(ArgumentError, %r{ambiguous wildcard})
        end
      end
    end
  end

  describe "#id" do
    subject { inhibitor.id }

    it { is_expected.to eq id }
    it { is_expected.to be_frozen }
  end

  describe "#treatment" do
    subject { inhibitor.treatment }

    it { is_expected.to eq treatment }
    it { is_expected.to be_frozen }
  end

  describe "#class_qualifier" do
    subject { inhibitor.class_qualifier }

    it { is_expected.to be_a Sidekiq::Antidote::ClassQualifier }
    it { is_expected.to be_frozen }
    it { is_expected.to have_attributes(pattern: class_qualifier) }
  end

  describe "#lethal?" do
    subject { inhibitor.lethal? }

    context "when treatment=skip" do
      let(:treatment) { "skip" }

      it { is_expected.to be false }
    end

    context "when treatment=kill" do
      let(:treatment) { "kill" }

      it { is_expected.to be true }
    end
  end

  describe "#match?" do
    subject { inhibitor.match?(Sidekiq::JobRecord.new(job_message)) }

    let(:class_qualifier) { "A::**Job" }
    let(:job_message)     { simple_job_message(klass: "A::B::CJob") }

    it { is_expected.to be true }

    context "with ActiveJob wrapper" do
      let(:job_message) { active_job_message(klass: "A::B::CJob") }

      it { is_expected.to be true }
    end
  end

  describe "#to_s" do
    subject { inhibitor.to_s }

    it { is_expected.to eq "#{treatment} #{class_qualifier}" }
  end

  describe "#eql?" do
    subject { inhibitor == other_inhibitor }

    let(:other_inhibitor) do
      described_class.new(id: id, treatment: treatment, class_qualifier: class_qualifier)
    end

    it { is_expected.to be true }

    context "when id mismatch" do
      let(:id)              { "one" }
      let(:other_inhibitor) { described_class.new(id: "two", treatment: treatment, class_qualifier: class_qualifier) }

      it { is_expected.to be false }
    end

    context "when treatment mismatch" do
      let(:treatment)       { "skip" }
      let(:other_inhibitor) { described_class.new(id: id, treatment: "kill", class_qualifier: class_qualifier) }

      it { is_expected.to be false }
    end

    context "when class qualifier mismatch" do
      let(:class_qualifier) { "DreamJob" }
      let(:other_inhibitor) { described_class.new(id: id, treatment: treatment, class_qualifier: "AnotherJob") }

      it { is_expected.to be false }
    end
  end

  describe "#==" do
    it "is an alias of #eql?" do
      expect(inhibitor.method(:==)).to eq inhibitor.method(:eql?)
    end
  end
end
