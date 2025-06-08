# frozen_string_literal: true

require "sidekiq"
require "sidekiq/web"

module Sidekiq
  module Antidote
    module Web
      ROOT  = Pathname.new(__dir__).join("../../../web").expand_path.realpath.freeze
      VIEWS = ROOT.join("views").freeze

      def self.registered(app) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        app.get("/antidote") do
          @inhibitors = Antidote.inhibitors

          erb(:index, views: VIEWS)
        end

        app.get("/antidote/add") do
          @treatment       = Sidekiq::Antidote::Inhibitor::TREATMENTS.first
          @class_qualifier = ""

          erb(:add, views: VIEWS)
        end

        app.post("/antidote/add") do
          @treatment       = request.params["treatment"]
          @treatment       = "skip" unless Sidekiq::Antidote::Inhibitor::TREATMENTS.include?(@treatment)
          @class_qualifier = request.params["class_qualifier"]
          @errors          = []

          begin
            Antidote.add(treatment: @treatment, class_qualifier: @class_qualifier)
            redirect "#{root_path}antidote"
          rescue StandardError => e
            @errors << e.message
            erb(:add, views: VIEWS)
          end
        end

        app.post("/antidote/:id/delete") do
          Antidote.delete(route_params(:id))

          redirect "#{root_path}antidote"
        end
      end
    end
  end
end

Sidekiq::Web.configure do |config|
  config.register_extension(
    Sidekiq::Antidote::Web,
    name:         "antidote",
    tab:          %w[Antidote],
    index:        %w[antidote],
    root_dir:     Sidekiq::Antidote::Web::ROOT.to_s,
    asset_paths:  %w[css]
  )
end
