# frozen_string_literal: true

require "capybara/rspec"
require "rack"
require "rack/session"
require "rack/test"
require "securerandom"

require "sidekiq/web"
require "sidekiq/antidote/web"

RSpec.describe Sidekiq::Antidote::Web, type: :feature do
  include Rack::Test::Methods

  def app
    @app ||= Rack::Builder.app do
      use Rack::Session::Cookie, secret: SecureRandom.hex(32), same_site: true
      run Sidekiq::Web
    end
  end

  def csrf_token
    SecureRandom.base64(Sidekiq::Web::CsrfProtection::TOKEN_LENGTH).tap do |csrf|
      env("rack.session", { csrf: csrf })
    end
  end

  before do
    Capybara.app = app
  end

  it "adds <Antidote> tab" do
    visit("/")

    expect(page).to have_link(href: "/antidote")
  end

  it "lists registered inhibitors" do
    alpha_inhibitor = Sidekiq::Antidote.add(treatment: "skip", class_qualifier: "AlphaJob")
    beta_inhibitor  = Sidekiq::Antidote.add(treatment: "kill", class_qualifier: "BetaJob")

    visit("/antidote")

    expect(find("tr#antidote-inhibitor-#{alpha_inhibitor.id}"))
      .to have_css("td", text: "skip")
      .and have_css("td", text: "AlphaJob")

    expect(find("tr#antidote-inhibitor-#{beta_inhibitor.id}"))
      .to have_css("td", text: "kill")
      .and have_css("td", text: "BetaJob")
  end

  describe "adding inhibitors" do
    before do
      Sidekiq::Antidote.add(treatment: "skip", class_qualifier: "AlphaJob")

      visit("/antidote")

      click_link(href: "/antidote/add")
    end

    it "allows adding <skip> inhibitors" do
      within("form#antidote-inhibitor") do
        select("skip", from: "antidote-inhibitor-treatment")
        fill_in("antidote-inhibitor-class-qualifier", with: "**Job")
        click_button("antidote-inhibitor-submit")
      end

      expect(Sidekiq::Antidote.inhibitors).to contain_exactly(
        have_attributes(treatment: "skip", class_qualifier: Sidekiq::Antidote::ClassQualifier.new("AlphaJob")),
        have_attributes(treatment: "skip", class_qualifier: Sidekiq::Antidote::ClassQualifier.new("**Job"))
      )

      expect(page).to have_current_path("/antidote")
    end

    it "allows adding <kill> inhibitors" do
      within("form#antidote-inhibitor") do
        select("kill", from: "antidote-inhibitor-treatment")
        fill_in("antidote-inhibitor-class-qualifier", with: "**Job")
        click_button("antidote-inhibitor-submit")
      end

      expect(Sidekiq::Antidote.inhibitors).to contain_exactly(
        have_attributes(treatment: "skip", class_qualifier: Sidekiq::Antidote::ClassQualifier.new("AlphaJob")),
        have_attributes(treatment: "kill", class_qualifier: Sidekiq::Antidote::ClassQualifier.new("**Job"))
      )

      expect(page).to have_current_path("/antidote")
    end

    it "shows error when class qualifier is invalid" do
      within("form#antidote-inhibitor") do
        select("kill", from: "antidote-inhibitor-treatment")
        fill_in("antidote-inhibitor-class-qualifier", with: "***Job")
        click_button("antidote-inhibitor-submit")
      end

      expect(Sidekiq::Antidote.inhibitors).to contain_exactly(
        have_attributes(treatment: "skip", class_qualifier: Sidekiq::Antidote::ClassQualifier.new("AlphaJob"))
      )

      expect(page).to have_current_path("/antidote/add").and have_css("#antidote-inhibitor-class-qualifier-error")
    end
  end

  describe "removing inhibitors" do
    before do
      Sidekiq::Antidote.add(treatment: "skip", class_qualifier: "AlphaJob")
      inhibitor = Sidekiq::Antidote.add(treatment: "kill", class_qualifier: "BetaJob")

      visit("/antidote")
      within("tr#antidote-inhibitor-#{CGI.escape(inhibitor.id)}") do
        click_button("delete")
      end
    end

    it "removes selected inhibitor" do
      expect(Sidekiq::Antidote.inhibitors).to contain_exactly(
        have_attributes(treatment: "skip", class_qualifier: Sidekiq::Antidote::ClassQualifier.new("AlphaJob"))
      )
    end
  end
end
